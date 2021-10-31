-- atc_rail.lua
-- registers and handles the ATC rail. Active component.
-- This is the only component that can interface with trains, so train interface goes here too.

--Using subtable
local r={}

-- Note on appr_internal:
-- The Approach callback is a special corner case: the train is not on the node, and it is executed synchronized 
-- (in the train step right during LZB traversal). We therefore need access to the train id and the lzbdata table
function r.fire_event(pos, evtdata, appr_internal)
	
	local ph=minetest.pos_to_string(pos)
	local railtbl = atlatc.active.nodes[ph]
	
	if not railtbl then
		atwarn("LuaATC interface rail at",ph,": Data not in memory! Please visit position and click 'Save'!")
		return
	end
	
	--prepare ingame API for ATC. Regenerate each time since pos needs to be known
	--If no train, then return false.
	
	-- try to get the train from the event data
	-- This workaround is required because the callback is one step delayed, and a fast train may have already left the node.
	-- Also used for approach callback
	local train_id = evtdata._train_id
	local atc_arrow = evtdata._train_arrow
	local train, tvel
	
	if train_id then
		train=advtrains.trains[train_id]
		-- speed
		tvel=train.velocity
	-- if still no train_id available, try to get the train at my position
	else
		train_id=advtrains.get_train_at_pos(pos)
		if train_id then
			train=advtrains.trains[train_id]
			advtrains.train_ensure_init(train_id, train)
			-- look up atc_arrow
			local index = advtrains.path_lookup(train, pos)
			atc_arrow = (train.path_cn[index] == 1)
			-- speed
			tvel=train.velocity
		end
	end
	
	local customfct={
		atc_send = function(cmd)
			if not train_id then return false end
			assertt(cmd, "string")
			advtrains.atc.train_set_command(train, cmd, atc_arrow)
			return true
		end,
		split_at_index = function(index, cmd)
			if not train_id then return false end
			assertt(cmd, "string")
			if type(index) ~= "number" or index < 2 then
				return false
			end
			local new_id = advtrains.split_train_at_index(train, index)
			if new_id then
				minetest.after(1,advtrains.atc.train_set_command,advtrains.trains[new_id], cmd, atc_arrow)
				return true
			end
			return false
		end,
		split_at_fc = function(cmd, len)
			assertt(cmd, "string")
			if not train_id then return false end
			local new_id, fc = advtrains.split_train_at_fc(train, false, len)
			if new_id then
				minetest.after(1,advtrains.atc.train_set_command,advtrains.trains[new_id], cmd, atc_arrow)
			end
			return fc or ""
		end,
		split_off_locomotive = function(cmd, len)
			assertt(cmd, "string")
			if not train_id then return false end
			local new_id, fc = advtrains.split_train_at_fc(train, true, len)
			if new_id then
				minetest.after(1,advtrains.atc.train_set_command,advtrains.trains[new_id], cmd, atc_arrow)
			end						
		end,
		train_length = function ()
			if not train_id then return false end
			return #train.trainparts
		end,
		step_fc = function()
			if not train_id then return false end
			advtrains.train_step_fc(train)
		end,
		set_shunt = function()
			-- enable shunting mode
			if not train_id then return false end
			train.is_shunt = true
		end,
		unset_shunt = function()
			if not train_id then return false end
			train.is_shunt = nil
		end,
		set_autocouple = function ()
			if not train_id then return false end
			train.autocouple = true			
		end,
		unset_autocouple = function ()
			if not train_id then return false end
			train.autocouple = nil
 		end,
		set_line = function(line)
			if type(line)~="string" and type(line)~="number" then
				return false
			end
			train.line = line .. ""
			minetest.after(0, advtrains.invalidate_path, train_id)
			return true
		end,
		get_line = function()
			return train.line
		end,
		set_rc = function(rc)
			if type(rc)~="string"then
				return false
			end
			train.routingcode = rc
			minetest.after(0, advtrains.invalidate_path, train_id)
			return true
		end,
		get_rc = function()
			return train.routingcode
		end,
		atc_reset = function(cmd)
			if not train_id then return false end
			assertt(cmd, "string")
			advtrains.atc.train_reset_command(train)
			return true
		end,
		atc_arrow = atc_arrow,
		atc_id = train_id,
		atc_speed = tvel,
		atc_set_text_outside = function(text)
			if not train_id then return false end
			if text then assertt(text, "string") end
			advtrains.trains[train_id].text_outside=text
			return true
		end,
		atc_set_text_inside = function(text)
			if not train_id then return false end
			if text then assertt(text, "string") end
			advtrains.trains[train_id].text_inside=text
			return true
		end,
		atc_get_text_outside = function()
			if not train_id then return false end
			return advtrains.trains[train_id].text_outside
		end,
		atc_get_text_inside = function(text)
			if not train_id then return false end
			return advtrains.trains[train_id].text_inside
		end,
		atc_set_lzb_tsr = function(speed)
			if not appr_internal then
				error("atc_set_lzb_tsr() can only be used during 'approach' events!")
			end
			assert(tonumber(speed), "Number expected!")
			
			local index = appr_internal.index
			advtrains.lzb_add_checkpoint(train, index, speed, nil)
			
			return true
		end,
	}
	-- interlocking specific
	if advtrains.interlocking then
		customfct.atc_set_ars_disable = function(value)
			advtrains.interlocking.ars_set_disable(train, value)
		end
	end
	
	atlatc.active.run_in_env(pos, evtdata, customfct)
	
end

advtrains.register_tracks("default", {
	nodename_prefix="advtrains_luaautomation:dtrack",
	texture_prefix="advtrains_dtrack_atc",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared_atc.png",
	description=atltrans("LuaATC Rail"),
	formats={},
	get_additional_definiton = function(def, preset, suffix, rotation)
		return {
			after_place_node = atlatc.active.after_place_node,
			after_dig_node = atlatc.active.after_dig_node,

			on_receive_fields = function(pos, ...)
				atlatc.active.on_receive_fields(pos, ...)
				
				--set arrowconn (for ATC)
				local ph=minetest.pos_to_string(pos)
				local _, conns=advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
				local nodeent = atlatc.active.nodes[ph]
				if nodeent then
					nodeent.arrowconn=conns[1].c
				end
			end,

			advtrains = {
				on_train_enter = function(pos, train_id, train, index)
					--do async. Event is fired in train steps
					atlatc.interrupt.add(0, pos, {type="train", train=true, id=train_id,
							_train_id = train_id, _train_arrow = (train.path_cn[index] == 1)})
				end,
				on_train_approach = function(pos, train_id, train, index, has_entered, lzbdata)
					-- Insert an event only if the rail indicated that it supports approach callbacks
					local ph=minetest.pos_to_string(pos)
					local railtbl = atlatc.active.nodes[ph]
					-- uses a "magic variable" in the local environment of the node
					-- This hack is necessary because code might not be prepared to get approach events...
					if railtbl and railtbl.data and railtbl.data.__approach_callback_mode then
						local acm = railtbl.data.__approach_callback_mode
						local in_arrow = (train.path_cn[index] == 1)
						if acm==2 or (acm==1 and in_arrow) then
							local evtdata = {type="approach", approach=true, id=train_id, has_entered = has_entered,
									_train_id = train_id, _train_arrow = in_arrow} -- reuses code from train_enter
							-- This event is *required* to run synchronously, because it might set the ars_disable flag on the train and add LZB checkpoints,
							-- although this is generally discouraged because this happens right in a train step
							-- At this moment, I am not aware whether this may cause side effects, and I must encourage users not to do expensive calculations here.
							r.fire_event(pos, evtdata, {train_id = train_id, train = train, index = index, lzbdata = lzbdata})
						end
					end
				end,
			},
			luaautomation = {
				fire_event=r.fire_event
			},
			digiline = {
				receptor = {},
				effector = {
					action = atlatc.active.on_digiline_receive
				},
			},
		}
	end,
}, advtrains.trackpresets.t_30deg_straightonly)


atlatc.rail = r
