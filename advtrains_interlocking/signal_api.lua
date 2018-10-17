-- Signal API implementation


--[[
Signal aspect table:
asp = {
	main = {
		free = <boolean>,
		speed = <int km/h>,
	},
	shunt = {
		free = <boolean>,
		-- Whether train may proceed as shunt move, on sight
		-- main aspect takes precedence over this
		proceed_as_main = <boolean>,
		-- If an approaching train is a shunt move and "main.free" is set,
		-- the train may proceed as a train move under the "main" aspect
		-- If this is not set, shunt moves are NOT allowed to switch to
		-- a train move, and must stop even if "main.free" is set.
		-- This is intended to be used for "Halt for shunt moves" signs.
	}
	dst = {
		free = <boolean>,
		speed = <int km/h>,
	}
	info = {
		call_on = <boolean>, -- Call-on route, expect train in track ahead
		dead_end = <boolean>, -- Route ends on a dead end (e.g. bumper)
		w_speed = <integer>,
		-- "Warning speed restriction". Supposed for short-term speed
		-- restrictions which always override any other restrictions
		-- imposed by "speed" fields, until lifted by a value of -1
	}
}
-- For "speed" and "w_speed" fields, a value of -1 means that the
-- restriction is lifted. If they are omitted, the value imposed at
-- the last aspect received remains valid.
-- The "dst" subtable can be completely omitted when no explicit dst
-- aspect should be signalled to the train. In this case, the last
-- signalled dst aspect remains valid.

== How signals actually work in here ==
Each signal (in the advtrains universe) is some node that has at least the
following things:
- An "influence point" that is set somewhere on a rail
- An aspect which trains that pass the "influence point" have to obey

There can be static and dynamic signals. Static signals are, roughly
spoken, signs, while dynamic signals are "real" signals which can display
different things.

The node definition of a signal node should contain those fields:
groups = {
  	advtrains_signal = 2,
	save_in_at_nodedb = 1,
}
advtrains = {
	function set_aspect(pos, node, asp)
		-- This function gets called whenever the signal should display
		-- a new or changed signal aspect. It is not required that
		-- the signal actually displays the exact same aspect, since
		-- some signals can not do this by design.
		-- Example: pure shunt signals can not display a "main" aspect
		-- and have no effect on train moves, so they will only ever
		-- honor the shunt.free field for their aspect.
		
		-- The aspect passed in here can always be queried using the
		-- advtrains.interlocking.signal_get_supposed_aspect(pos) function.
		-- It is always DANGER when the signal is not used as route signal.
		
		-- For static signals, this function should be completely omitted
		-- If this function is omitted, it won't be possible to use
		-- route setting on this signal.
	end
	function get_aspect(pos, node)
		-- This function gets called by the train safety system. It
		should return the aspect that this signal actually displays,
		not preferably the input of set_aspect.
		-- For regular, full-featured light signals, they will probably
		honor all entries in the original aspect, however, e.g.
		simple shunt signals always return main.free=true regardless of
		the set_aspect input because they can not signal "Halt" to
		train moves.
		-- advtrains.interlocking.DANGER contains a default "all-danger" aspect.
	end
}
on_rightclick = advtrains.interlocking.signal_rc_handler
can_dig =  advtrains.interlocking.signal_can_dig
after_dig_node = advtrains.interlocking.signal_after_dig

(If you need to specify custom can_dig or after_dig_node callbacks,
please call those functions anyway!)

Important note: If your signal should support external ways to set its
aspect (e.g. via mesecons), there are some things that need to be considered:
- advtrains.interlocking.signal_get_supposed_aspect(pos) won't respect this
- Whenever you change the signal aspect, and that aspect change
did not happen through a call to
advtrains.interlocking.signal_set_aspect(pos, asp), you are
*required* to call this function:
advtrains.interlocking.signal_on_aspect_changed(pos)
in order to notify trains about the aspect change.
This function will query get_aspect to retrieve the new aspect.

]]--

local DANGER = {
	main = {
		free = false,
		speed = 0,
	},
	shunt = {
		free = false,
	},
	dst = {
		free = false,
		speed = 0,
	},
	info = {}
}
advtrains.interlocking.DANGER = DANGER

function advtrains.interlocking.update_signal_aspect(tcbs)
	if tcbs.signal then
		local asp = tcbs.aspect or DANGER
		advtrains.interlocking.signal_set_aspect(tcbs.signal, asp)
	end
end

function advtrains.interlocking.signal_can_dig(pos)
	return not advtrains.interlocking.db.get_sigd_for_signal(pos)
end

function advtrains.interlocking.signal_after_dig(pos)
	-- clear influence point
	advtrains.interlocking.db.clear_ip_by_signalpos(pos)
end

function advtrains.interlocking.signal_set_aspect(pos, asp)
	local node=advtrains.ndb.get_node(pos)
	local ndef=minetest.registered_nodes[node.name]
	if ndef and ndef.advtrains and ndef.advtrains.set_aspect then
		ndef.advtrains.set_aspect(pos, node, asp)
		advtrains.interlocking.signal_on_aspect_changed(pos)
	end
end

-- should be called when aspect has changed on this signal.
function advtrains.interlocking.signal_on_aspect_changed(pos)
	local ipts, iconn = advtrains.interlocking.db.get_ip_by_signalpos(pos)
	if not ipts then return end
	local ipos = minetest.string_to_pos(ipts)
	
	local tns = advtrains.occ.get_trains_over(ipos)
	for id, sidx in pairs(tns) do
		local train = advtrains.trains[id]
		if train.index <= sidx then
			advtrains.interlocking.lzb_invalidate(train)
		end
	end
end

function advtrains.interlocking.signal_rc_handler(pos, node, player, itemstack, pointed_thing)
	local pname = player:get_player_name()
	local sigd = advtrains.interlocking.db.get_sigd_for_signal(pos)
	if sigd then
		advtrains.interlocking.show_signalling_form(sigd, pname)
	else
		-- permit to set aspect manually
		minetest.show_formspec(pname, "at_il_sigasp_"..minetest.pos_to_string(pos), "field[aspect;Set Aspect (F/D)Speed(F/D)Speed(F/D) ['A' to assign IP];D0D0D]")
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local pts = string.match(formname, "^at_il_sigasp_(.+)$")
	local pos
	if pts then pos = minetest.string_to_pos(pts) end
	if pos and fields.aspect then
		if fields.aspect == "A" then
			advtrains.interlocking.show_ip_form(pos, pname)
			return
		end
		local mfs, msps, dfs, dsps, shs = string.match(fields.aspect, "^([FD])([0-9]+)([FD])([0-9]+)([FD])$")
		local asp = {
			main = {
				free = mfs=="F",
				speed = tonumber(msps),
			},
			shunt = {
				free = shs=="F",
			},
			dst = {
				free = dfs=="F",
				speed = tonumber(dsps),
			},
			info = {
				call_on = false, -- Call-on route, expect train in track ahead
				dead_end = false, -- Route ends on a dead end (e.g. bumper)
			}
		}
		advtrains.interlocking.signal_set_aspect(pos, asp)
	end
end)

-- Returns the aspect the signal at pos is supposed to show
function advtrains.interlocking.signal_get_supposed_aspect(pos)
	local sigd = advtrains.interlocking.db.get_sigd_for_signal(pos)
	if sigd then
		local tcbs = advtrains.interlocking.db.get_tcbs(sigd)
		if tcbs.aspect then
			return tcbs.aspect
		end
	end
	return DANGER;
end

-- Returns the actual aspect of the signal at position, as returned by the nodedef.
-- returns nil
function advtrains.interlocking.signal_get_aspect(pos)
	local node=advtrains.ndb.get_node(pos)
	local ndef=minetest.registered_nodes[node.name]
	if ndef and ndef.advtrains and ndef.advtrains.get_aspect then
		return ndef.advtrains.get_aspect(pos, node)
	end
end

local players_assign_ip = {}

-- shows small info form for signal IP state/assignment
-- only_notset: show only if it is not set yet (used by signal tcb assignment)
function advtrains.interlocking.show_ip_form(pos, pname, only_notset)
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	local form = "size[7,5]label[0.5,0.5;Signal at "..minetest.pos_to_string(pos).."]"
	local pts, connid = advtrains.interlocking.db.get_ip_by_signalpos(pos)
	if pts then
		form = form.."label[0.5,1.5;Influence point is set at "..pts.."/"..connid.."]"
		form = form.."button_exit[0.5,2.5;  5,1;show;Show]"
		form = form.."button_exit[0.5,3.5;  5,1;clear;Clear]"
	else
		form = form.."label[0.5,1.5;Influence point is not set.]"
		form = form.."label[0.5,2.0;It is recommended to set an influence point.]"
		form = form.."label[0.5,2.5;This is the point where trains will obey the signal.]"
		
		form = form.."button_exit[0.5,3.5;  5,1;set;Set]"
	end
	if not only_notset or not pts then
		minetest.show_formspec(pname, "at_il_ipassign_"..minetest.pos_to_string(pos), form)
	end
end

local function ipmarker(ipos, connid)
	local node_ok, conns, rhe = advtrains.get_rail_info_at(ipos, advtrains.all_tracktypes)
	if not node_ok then return end
	local yaw = advtrains.dir_to_angle(conns[connid].c)
	
	-- using tcbmarker here
	local obj = minetest.add_entity(vector.add(ipos, {x=0, y=0.2, z=0}), "advtrains_interlocking:tcbmarker")
	if not obj then return end
	obj:set_yaw(yaw)
	obj:set_properties({
		textures = { "at_il_signal_ip.png" },
	})
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, {train_operator=true, interlocking=true}) then
		return
	end
	local pts = string.match(formname, "^at_il_ipassign_([^_]+)$")
	local pos
	if pts then
		pos = minetest.string_to_pos(pts)
	end
	if pos then
		if fields.set then
			advtrains.interlocking.signal_init_ip_assign(pos, pname)
		elseif fields.clear then
			advtrains.interlocking.db.clear_ip_by_signalpos(pos)
		elseif fields.show then
			local ipts, connid = advtrains.interlocking.db.get_ip_by_signalpos(pos)
			if not ipts then return end
			local ipos = minetest.string_to_pos(ipts)
			ipmarker(ipos, connid)
		end
	end
end)

-- inits the signal IP assignment process
function advtrains.interlocking.signal_init_ip_assign(pos, pname)
	if not minetest.check_player_privs(pname, "interlocking") then
		minetest.chat_send_player(pname, "Insufficient privileges to use this!")
		return
	end
	--remove old IP
	advtrains.interlocking.db.clear_ip_by_signalpos(pos)
	minetest.chat_send_player(pname, "Configuring Signal: Please look in train's driving direction and punch rail to set influence point.")
	
	players_assign_ip[pname] = pos
end

minetest.register_on_punchnode(function(pos, node, player, pointed_thing)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	-- IP assignment
	local signalpos = players_assign_ip[pname]
	if signalpos then
		if vector.distance(pos, signalpos)<=50 then
			local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
			if node_ok and #conns == 2 then
				
				local yaw = player:get_look_horizontal()
				local plconnid = advtrains.yawToClosestConn(yaw, conns)
				
				-- add assignment if not already present.
				local pts = advtrains.roundfloorpts(pos)
				if not advtrains.interlocking.db.get_ip_signal_asp(pts, plconnid) then
					advtrains.interlocking.db.set_ip_signal(pts, plconnid, signalpos)
					ipmarker(pos, plconnid)
					minetest.chat_send_player(pname, "Configuring Signal: Successfully set influence point")
				else
					minetest.chat_send_player(pname, "Configuring Signal: Influence point of another signal is already present!")
				end
			else
				minetest.chat_send_player(pname, "Configuring Signal: This is not a normal two-connection rail! Aborted.")
			end
		else
			minetest.chat_send_player(pname, "Configuring Signal: Node is too far away. Aborted.")
		end
		players_assign_ip[pname] = nil
	end
end)
