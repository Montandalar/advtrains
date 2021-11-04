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
	-- index of initiating train is set so that it matches the front pos of stationary train
	-- remove stationary train
	-- wagons of stationary train are inserted at the beginning of initiating train (considers direction of stat_train and inserts reverse if required)

-- train.couple_* contain references to ObjectRefs of couple objects, which contain all relevant information
-- These objectRefs will delete themselves once the couples no longer match (see below)

advtrains.coupler_types = {}

function advtrains.register_coupler_type(code, name)
	advtrains.coupler_types[code] = name
end

-- Register some default couplers
advtrains.register_coupler_type("chain", attrans("Buffer and Chain Coupler"))
advtrains.register_coupler_type("scharfenberg", attrans("Scharfenberg Coupler"))


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
	--atdebug("Couple init autocouple=",init_train.autocouple,"atc_w_acpl=",init_train.atc_wait_autocouple)
	if init_train.autocouple or init_train.atc_wait_autocouple then
		local cplmatch, msg = advtrains.check_matching_coupler_types(init_train, true, stat_train, stat_is_front)
		if cplmatch then
			advtrains.couple_trains(init_train, false, stat_train, stat_is_front)
			-- clear atc couple waiting blocker
			init_train.atc_wait_autocouple = nil
			return
		end
	end
	-- get here if either autocouple is not on or couples dont match
	local pos = advtrains.path_get_interpolated(init_train, init_train.index)
	create_couple_entity(pos, init_train, true, stat_train, stat_is_front)
	-- clear ATC command on collision
	advtrains.atc.train_reset_command(init_train)

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

		local cplmatch, msg = advtrains.check_matching_coupler_types(train1, t1_is_front, train2, t2_is_front)
		if cplmatch then
			advtrains.couple_trains(train1, not t1_is_front, train2, t2_is_front)
		else
			minetest.chat_send_player(pname, msg)
		end
	end
end

-- Actually performs the train coupling. Always retains train ID of train1
function advtrains.couple_trains(init_train, invert_init_train, stat_train, stat_train_opposite)
	--atdebug("Couple trains init=",init_train.id,"initinv=",invert_init_train,"stat=",stat_train.id,"statreverse=",stat_train_opposite)

	if not advtrains.train_ensure_init(init_train.id, init_train) then
		atwarn("Coupling: initiating train",init_train.id,"is not initialized! Operation aborted!")
		return
	end
	if not advtrains.train_ensure_init(stat_train.id, stat_train) then
		atwarn("Coupling: stationary train",stat_train.id,"is not initialized! Operation aborted!")
		return
	end

	-- only used with the couple entity
	if invert_init_train then
		advtrains.invert_train(init_train.id)
	end

	local itp = init_train.trainparts
	local init_wagoncnt = #itp
	local stp = stat_train.trainparts
	local stat_wagoncnt = #stp
	local stat_trainlen = stat_train.trainlen -- save the train length of stat train, to be added to index

	if stat_train_opposite then
		-- insert wagons in inverse order and set their wagon_flipped state
		for i=1,stat_wagoncnt do
			table.insert(itp, 1, stp[i])
			local wdata = advtrains.wagons[stp[i]]
			if wdata then
				wdata.wagon_flipped = not wdata.wagon_flipped
			else
				atwarn("While coupling, wagon",stp[i],"of stationary train",stat_train.id,"not found!")
			end
		end
	else
		--insert wagons in normal order
		for i=stat_wagoncnt,1,-1 do
			table.insert(itp, 1, stp[i])
		end
	end

	-- TODO: migrate some of the properties from stat_train to init_train?
	
	advtrains.remove_train(stat_train.id)

	-- Set train index forward
	init_train.index = advtrains.path_get_index_by_offset(init_train, init_train.index, stat_trainlen)

	advtrains.update_trainpart_properties(init_train.id)
	advtrains.update_train_start_and_end(init_train)

	advtrains.couple_invalidate(init_train)
	return true
end

-- Couple types matching check
-- returns: true, nil if OK
--			false, errmsg if there is an error
function advtrains.check_matching_coupler_types(t1, t1_front, t2, t2_front)
	-- 1. get wagons
	local t1_wid
	if t1_front then
		t1_wid = t1.trainparts[1]
	else
		t1_wid = t1.trainparts[#t1.trainparts]
	end
	local t2_wid
	if t2_front then
		t2_wid = t2.trainparts[1]
	else
		t2_wid = t2.trainparts[#t2.trainparts]
	end

	--atdebug("CMCT: t1_wid",t1_wid,"t2_wid",t2_wid,"")

	if not t1_wid or not t2_wid then
		return false, "Unable to retrieve wagons from train"--note: no translation needed, case should not occur
	end

	local t1_wagon = advtrains.wagons[t1_wid]
	local t2_wagon = advtrains.wagons[t2_wid]

	if not t1_wagon or not t2_wagon then
		return false, "At least one of wagons "..t1_wagon.." or "..t2_wagon.." does not exist"--note: no translation needed, case should not occur
	end

	-- these calls do not fail, they may return placeholder - doesn't matter
	local _,t1_wpro = advtrains.get_wagon_prototype(t1_wagon)
	local _,t2_wpro = advtrains.get_wagon_prototype(t2_wagon)

	-- get correct couplers table (front/back)
	local t1_cplt
	if not t1_front == not t1_wagon.wagon_flipped then --fancy XOR
		t1_cplt = t1_wpro.coupler_types_back
	else
		t1_cplt = t1_wpro.coupler_types_front
	end
	local t2_cplt
	if not t2_front == not t2_wagon.wagon_flipped then --fancy XOR
		t2_cplt = t2_wpro.coupler_types_back
	else
		t2_cplt = t2_wpro.coupler_types_front
	end

	--atdebug("CMCT: t1",t1_cplt,"t2",t2_cplt,"")

	-- if at least one of the trains has no couplers table, it always couples (fallback behavior and mode for universal shunters)
	if not t1_cplt or not t2_cplt then
		return true
	end

	-- have common coupler?
	for typ,_ in pairs(t1_cplt) do
		if t2_cplt[typ] then
			--atdebug("CMCT: Matching type",typ)
			return true
		end
	end
	--no match, give user an info
	local t1_cplhr, t2_cplhr = {},{}
	for typ,_ in pairs(t1_cplt) do
		table.insert(t1_cplhr, advtrains.coupler_types[typ] or typ)
	end
	if #t1_cplhr==0 then t1_cplhr[1]=attrans("<none>") end
	for typ,_ in pairs(t2_cplt) do
		table.insert(t2_cplhr, advtrains.coupler_types[typ] or typ)
	end
	if #t2_cplhr==0 then t2_cplhr[1]=attrans("<none>") end
	return false, attrans("Can not couple: The couplers of the trains do not match (@1 and @2).", table.concat(t1_cplhr, ","), table.concat(t2_cplhr, ","))
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
