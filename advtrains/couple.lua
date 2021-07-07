--couple.lua
--Handles coupling and discoupling of trains, and defines the coupling entities
--Rework June 2021 - some functions from trainlogic.lua have been moved here

-- COUPLING --
-- During coupling rework, the behavior of coupling was changed to make automation easier. It is now as follows:
-- Coupling is only ever initiated when a train is standing somewhere (not moving) and another train drives onto one of its ends
-- with a speed greater than 0
-- "stationary" train is the one standing there - in old code called "train2"
-- "initiating" train is the one that approached it and bumped into it - typically an engine - in old code called "train1"
-- When the initiating train has autocouple set, trains are immediately coupled
-- When not, a couple entity is spawned and coupling commences on click
-- Coupling MUST preserve the train ID of the initiating train, so it is done like this:
	-- initiating train is reversed
	-- stationary train is reversed if required, so that it points towards the initiating train
	-- do_connect_trains(initiating, stationary)
-- As a result, the coupled train is reversed in direction. Alternative way of doing things (might be considered later):
	-- stationary train is reversed if required, so that it points away from the initiating train
	-- index of initiating train is set so that it matches the front pos of stationary train
	-- wagons of stationary train are inserted at the beginning of initiating train
	-- remove stationary train

-- train.couple_* contain references to ObjectRefs of couple objects, which contain all relevant information
-- These objectRefs will delete themselves once the couples no longer match (see below)
local function create_couple_entity(pos, train1, t1_is_front, train2, t2_is_front)
	local id1 = train1.id
	local id2 = train2.id

	-- delete previous couple entities
	if t1_is_front then
		if train1.cpl_front then train1.cpl_front:remove() end
	else
		if train1.cpl_back then train1.cpl_back:remove() end
	end
	if t2_is_front then
		if train2.cpl_front then train2.cpl_front:remove() end
	else
		if train2.cpl_back then train2.cpl_back:remove() end
	end
	
	local obj=minetest.add_entity(pos, "advtrains:couple")
	if not obj then error("Failed creating couple object!") return end
	local le=obj:get_luaentity()
	le.train_id_1=id1
	le.t1_is_front=t1_is_front
	le.train_id_2=id2
	le.t2_is_front=t2_is_front
	--atdebug("created couple between",train1.id,train2.id,t2_is_front)
	
	if t1_is_front then
		train1.cpl_front = obj
	else
		train2.cpl_back = obj
	end
	if t2_is_front then
		train2.cpl_front = obj
	else
		train2.cpl_back = obj
	end
end

-- Old static couple checking. Never used for autocouple, only used for standing trains if train did not approach
local CPL_CHK_DST = -1
local CPL_ZONE = 2
function advtrains.train_check_couples(train)
	--atdebug("rechecking couples")
	if train.cpl_front then
		if not train.cpl_front:get_yaw() then
			-- objectref is no longer valid. reset.
			train.cpl_front = nil
		end
	end
	if not train.cpl_front then
		-- recheck front couple
		local front_trains, pos = advtrains.occ.get_occupations(train, atround(train.index) + CPL_CHK_DST)
		if advtrains.is_node_loaded(pos) then -- if the position is loaded...
			for tid, idx in pairs(front_trains) do
				local other_train = advtrains.trains[tid]
				if not advtrains.train_ensure_init(tid, other_train) then
					atwarn("Train",tid,"is not initialized! Couldn't check couples!")
					return
				end
				--atdebug(train.id,"front: ",idx,"on",tid,atround(other_train.index),atround(other_train.end_index))
				if other_train.velocity == 0 then
					if idx>=other_train.index and idx<=other_train.index + CPL_ZONE then
							create_couple_entity(pos, train, true, other_train, true)
							break
					end
					if idx<=other_train.end_index and idx>=other_train.end_index - CPL_ZONE then
							create_couple_entity(pos, train, true, other_train, false)
							break
					end
				end
			end
		end
	end
	if train.cpl_back then
		if not train.cpl_back:get_yaw() then
			-- objectref is no longer valid. reset.
			train.cpl_back = nil
		end
	end
	if not train.cpl_back then
		-- recheck back couple
		local back_trains, pos = advtrains.occ.get_occupations(train, atround(train.end_index) - CPL_CHK_DST)
		if advtrains.is_node_loaded(pos) then -- if the position is loaded...
			for tid, idx in pairs(back_trains) do
				local other_train = advtrains.trains[tid]
				if not advtrains.train_ensure_init(tid, other_train) then
					atwarn("Train",tid,"is not initialized! Couldn't check couples!")
					return
				end
				--atdebug(train.id,"back: ",idx,"on",tid,atround(other_train.index),atround(other_train.end_index))
				if other_train.velocity == 0 then
					if idx>=other_train.index and idx<=other_train.index + CPL_ZONE then
							create_couple_entity(pos, train, false, other_train, true)
							break
					end
					if idx<=other_train.end_index and idx>=other_train.end_index - CPL_ZONE then
							create_couple_entity(pos, train, false, other_train, false)
							break
					end
				end
			end
		end
	end
end

-- Deletes couple entities from the train
function advtrains.couple_invalidate(train)
	if train.cpl_back then
		train.cpl_back:remove()
		train.cpl_back = nil
	end
	if train.cpl_front then
		train.cpl_front:remove()
		train.cpl_front = nil
	end
	train.couples_up_to_date = nil
end

-- Called from train_step_b() when the current train (init_train) just stopped at one of the end indices of another train (stat_train)
-- Depending on autocouple, either couples immediately or spawns a couple entity
function advtrains.couple_initiate_with(init_train, stat_train, stat_is_front)
	--atdebug("Initiating couplign between init=",init_train.id,"stat=",stat_train.id,"backside=",stat_is_backside)
	if init_train.autocouple then
		advtrains.couple_trains(init_train, true, stat_train, stat_is_front)
	else
		local pos = advtrains.path_get_interpolated(init_train, init_train.index)
		create_couple_entity(pos, init_train, true, stat_train, stat_is_front)
	end
	
end

-- check if the player has permission for the first/last wagon of the train
local function check_twagon_owner(train, b_first, pname)
	local wtp = b_first and 1 or #train.trainparts
	local wid = train.trainparts[wtp]
	local wdata = advtrains.wagons[wid]
	if wdata then
		return advtrains.check_driving_couple_protection(pname, wdata.owner, wdata.whitelist)
	end
	return false
end

-- Perform coupling, but check if the player is authorized to couple
function advtrains.safe_couple_trains(train1, t1_is_front, train2, t2_is_front, pname)

	if pname and not minetest.check_player_privs(pname, "train_operator") then
		   minetest.chat_send_player(pname, "Missing train_operator privilege")
		   return false
	end

	local wck_t1, wck_t2
	if pname then
		   wck_t1 = check_twagon_owner(train1, t1_is_front, pname)
		   wck_t2 = check_twagon_owner(train2, t2_is_front, pname)
	end
	if (wck_t1 or wck_t2) or not pname then
		advtrains.couple_trains(train1, t1_is_front, train2, t2_is_front)
	end
end

-- Actually performs the train coupling. Always retains train ID of train1
function advtrains.couple_trains(train1, t1_is_front, train2, t2_is_front)
	--atdebug("Couple trains init=",init_train.id,"stat=",stat_train.id,"statreverse=",stat_must_reverse)
	-- see comment on top of file
	if t1_is_front then
		advtrains.invert_train(train1.id)
	end
	if not t2_is_front then
		advtrains.invert_train(train2.id)
	end

	advtrains.do_connect_trains(train1, train2)
end

-- Adds the wagons of first to second and deletes second_id afterwards
-- Assumes that second_id stands right behind first_id and both trains point to the same direction
function advtrains.do_connect_trains(first, second)
	
	if not advtrains.train_ensure_init(first.id, first) then
		atwarn("Coupling: first train",first.id,"is not initialized! Operation aborted!")
		return
	end
	if not advtrains.train_ensure_init(second.id, second) then
		atwarn("Coupling: second train",second.id,"is not initialized! Operation aborted!")
		return
	end
	
	local first_wagoncnt=#first.trainparts
	local second_wagoncnt=#second.trainparts
	
	for _,v in ipairs(second.trainparts) do
		table.insert(first.trainparts, v)
	end
	
	advtrains.remove_train(second.id)

	first.velocity = 0
	
	advtrains.update_trainpart_properties(first.id)
	advtrains.couple_invalidate(first)
	return true
end



-- DECOUPLING --
function advtrains.split_train_at_fc(train, count_empty, length_limit)
	-- splits train at first different current FC by convention,
	-- locomotives have empty FC so are ignored
	-- count_empty is used to split off locomotives
	-- length_limit limits the length of the first train to length_limit wagons
	local train_id = train.id
	local fc = false
	local ind = 0
	for i = 1, #train.trainparts do
		local w_id = train.trainparts[i]
		local data = advtrains.wagons[w_id]
		if length_limit and i > length_limit then
			ind = i
			break
		end
		if data then
			local wfc = advtrains.get_cur_fc(data)
			if  wfc ~= "" or count_empty then
				if  fc then
					if fc ~= wfc then
						ind = i
						break
					end
				else
					fc = wfc
				end
			end
		end
	end
	if ind > 0 then
		return advtrains.split_train_at_index(train, ind), fc
	end
	if fc then
		return nil, fc
	end
end

function advtrains.train_step_fc(train)
	for i=1,#train.trainparts do
		local w_id = train.trainparts[i]
		local data = advtrains.wagons[w_id]
		if data then
			advtrains.step_fc(data)
		end
	end
end


-- split_train_at_index() is in trainlogic.lua because it needs access to two local functions

function advtrains.split_train_at_wagon(wagon_id)
	--get train
	local data = advtrains.wagons[wagon_id]
	advtrains.split_train_at_index(advtrains.trains[data.train_id], data.pos_in_trainparts)
end


-- COUPLE ENTITIES --

local couple_max_dist=3

minetest.register_entity("advtrains:discouple", {
	visual="sprite",
	textures = {"advtrains_discouple.png"},
	collisionbox = {-0.3,-0.3,-0.3, 0.3,0.3,0.3},
	visual_size = {x=0.7, y=0.7},
	initial_sprite_basepos = {x=0, y=0},
	
	is_discouple=true,
	static_save = false,
	on_activate=function(self, staticdata) 
		if staticdata=="DISCOUPLE" then
			--couple entities have no right to exist further...
			atprint("Discouple loaded from staticdata, destroying")
			self.object:remove()
			return
		end
		self.object:set_armor_groups({immortal=1})
	end,
	get_staticdata=function() return "DISCOUPLE" end,
	on_punch=function(self, player)
			local pname = player:get_player_name()
			if pname and pname~="" and self.wagon then
				if advtrains.safe_decouple_wagon(self.wagon.id, pname) then
					self.object:remove()
				end
			end
	end,
	on_step=function(self, dtime)
			if not self.wagon then
				self.object:remove()
				return
			end
			--getyaw seems to be a reliable method to check if an object is loaded...if it returns nil, it is not.
			if not self.wagon.object:get_yaw() then
				self.object:remove()
				return
			end
			if not self.wagon:train() or self.wagon:train().velocity > 0 then
				self.object:remove()
				return
			end
	end,
})

-- advtrains:couple
-- Couple entity 

minetest.register_entity("advtrains:couple", {
	visual="sprite",
	textures = {"advtrains_couple.png"},
	collisionbox = {-0.3,-0.3,-0.3, 0.3,0.3,0.3},
	visual_size = {x=0.7, y=0.7},
	initial_sprite_basepos = {x=0, y=0},
	
	is_couple=true,
	static_save = false,
	on_activate=function(self, staticdata)
		if staticdata=="COUPLE" then
			--couple entities have no right to exist further...
			--atdebug("Couple loaded from staticdata, destroying")
			self.object:remove()
			return
		end
		self.object:set_armor_groups({immmortal=1})
	end,
	get_staticdata=function(self) return "COUPLE" end,
	on_rightclick=function(self, clicker)
		if not self.train_id_1 or not self.train_id_2 then return end

		local pname=clicker
		if type(clicker)~="string" then pname=clicker:get_player_name() end

		local train1=advtrains.trains[self.train_id_1]
		local train2=advtrains.trains[self.train_id_2]

		advtrains.safe_couple_trains(train1, self.t1_is_front, train2, self.t2_is_front, pname)
		self.object:remove()
	end,
	on_step=function(self, dtime)
		if advtrains.wagon_outside_range(self.object:getpos()) then
			--atdebug("Couple Removing outside range")
			self.object:remove()
			return
		end

		if not self.train_id_1 or not self.train_id_2 then
			--atdebug("Couple Removing ids missing")
			self.object:remove()
			return
		end
		local train1=advtrains.trains[self.train_id_1]
		local train2=advtrains.trains[self.train_id_2]
		if not train1 or not train2 then
			--atdebug("Couple Removing trains missing")
			self.object:remove()
			return
		end
		
		if self.position_set and train1.velocity>0 or train2.velocity>0 then
			--atdebug("Couple: train is moving, destroying")
			self.object:remove()
			return
		end

		if not self.position_set then
			local tp1
			if self.t1_is_front then
				tp1=advtrains.path_get_interpolated(train1, train1.index)
			else
				tp1=advtrains.path_get_interpolated(train1, train1.end_index)
			end
			local tp2
			if self.t2_is_front then
				tp2=advtrains.path_get_interpolated(train2, train2.index)
			else
				tp2=advtrains.path_get_interpolated(train2, train2.end_index)
			end
			local pos_median=advtrains.pos_median(tp1, tp2)
			if not vector.equals(pos_median, self.object:getpos()) then
				self.object:set_pos(pos_median)
			end
			self.position_set=true
		end
	end,
})
