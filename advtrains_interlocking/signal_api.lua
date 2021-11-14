-- Signal API implementation


--[[
Signal aspect table:
Note: All speeds are measured in m/s, aka the number of + signs in the HUD.
asp = {
	main = <int speed>,
		-- Main signal aspect, tells state and permitted speed of next section
		-- 0 = section is blocked
		-- >0 = section is free, speed limit is this value
		-- -1 = section is free, maximum speed permitted
		-- false/nil = Signal doesn't provide main signal information, retain current speed limit.
	shunt = <boolean>,
		-- Whether train may proceed as shunt move, on sight
		-- main aspect takes precedence over this
		-- When main==0, train switches to shunt move and is restricted to speed 6
	proceed_as_main = <boolean>,
		-- If an approaching train is a shunt move and 'shunt' is false,
		-- the train may proceed as a train move under the "main" aspect
		-- if the main aspect permits it (i.e. main!=0)
		-- If this is not set, shunt moves are NOT allowed to switch to
		-- a train move, and must stop even if "main" would permit passing.
		-- This is intended to be used for "Halt for shunt moves" signs.
	
	dst = <int speed>,
		-- Distant signal aspect, tells state and permitted speed of the section after next section
		-- The character of these information is purely informational
		-- At this time, this field is not actively used
		-- 0 = section is blocked
		-- >0 = section is free, speed limit is this value
		-- -1 = section is free, maximum speed permitted
		-- false/nil = Signal doesn't provide distant signal information.
	
	-- the character of call_on and dead_end is purely informative
	call_on = <boolean>, -- Call-on route, expect train in track ahead (not implemented yet)
	dead_end = <boolean>, -- Route ends on a dead end (e.g. bumper) (not implemented yet)

	w_speed = <integer>,
	-- "Warning speed restriction". Supposed for short-term speed
	-- restrictions which always override any other restrictions
	-- imposed by "speed" fields, until lifted by a value of -1
	-- (Example: german Langsamfahrstellen-Signale)
	}
}

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
	set_aspect = function(pos, node, asp)
		-- This function gets called whenever the signal should display
		-- a new or changed signal aspect. It is not required that
		-- the signal actually displays the exact same aspect, since
		-- some signals can not do this by design. However, it must
		-- display an aspect that is at least as restrictive as the passed
		-- aspect as far as it is capable of doing so.
		-- Examples:
		-- - pure shunt signals can not display a "main" aspect
		--   and have no effect on train moves, so they will only ever
		--   honor the shunt.free field for their aspect.
		-- - the german Hl system can only signal speeds of 40, 60
		--   and 100 km/h, a speed of 80km/h should then be signalled
		--   as 60 km/h instead.
		-- In turn, it is not guaranteed that the aspect will fulfill the
		-- criteria put down in supported_aspects.
		-- If set_aspect is present, supported_aspects should also be declared.
		
		-- The aspect passed in here can always be queried using the
		-- advtrains.interlocking.signal_get_supposed_aspect(pos) function.
		-- It is always DANGER when the signal is not used as route signal.
		
		-- For static signals, this function should be completely omitted
		-- If this function is omitted, it won't be possible to use
		-- route setting on this signal.
	end,
	supported_aspects = {
		-- A table which tells which different types of aspects this signal
		--  is able to display. It is used to construct the "aspect editing"
		--  formspec for route programming (and others) It should always be
		--  present alongside with set_aspect. If this is not specified but
		--  set_aspect is, the user will be allowed to select any aspect.
		-- Any of the fields marked with <boolean/nil> support 3 types of values:
				nil: if this signal can switch between free/blocked
				false: always shows "blocked", unchangable
				true: always shows "free", unchangable
		-- Any of the "speed" fields should contain a list of possible values
		--  to be set as restriction. If omitted, the value of the described
		--  field is always assumed to be false (no information)
		-- A speed of 0 means that the signal can show a "blocked" aspect
		--  (which is probably the case for most signals)
		-- If the signal can signal "no information" on one of the fields
		--  (thus false is an acceptable value), include false in the list
		-- If your signal can only display a single speed (may it be -1),
		--  always enclose that single value into a list. (such as {-1})
		main = {<speed1>, ..., <speedn>} or nil,
		dst = {<speed1>, ..., <speedn>} or nil,
		shunt = <boolean/nil>,
		
		call_on = <boolean/nil>,
		dead_end = <boolean/nil>,
		w_speed = {<speed1>, ..., <speedn>} or nil,
		
	},
	Example for supported_aspects:
	supported_aspects = {
		main = {0, 6, -1}, -- can show either "Section blocked", "Proceed at speed 6" or "Proceed at maximum speed"
		dst = {0, false}, -- can show only if next signal shows "blocked", no other information.
		shunt = false, -- shunting by this signal is never allowed.
		
		call_on = false,
		dead_end = false,
		w_speed = nil,
		-- none of the information can be shown by the signal
		
	},
	
	get_aspect = function(pos, node)
		-- This function gets called by the train safety system. It
		should return the aspect that this signal actually displays,
		not preferably the input of set_aspect.
		-- For regular, full-featured light signals, they will probably
		honor all entries in the original aspect, however, e.g.
		simple shunt signals always return main=false regardless of
		the set_aspect input because they can not signal "Halt" to
		train moves.
		-- advtrains.interlocking.DANGER contains a default "all-danger" aspect.
		-- If your signal does not cover certain sub-tables of the aspect,
		the following reasonable defaults are automatically assumed:
		main = false (unchanged)
		dst = false (unchanged)
		shunt = false (shunting not allowed)
		info = {} (no further information)
	end,
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
	main = 0,
	dst = false,
	shunt = false,
}
advtrains.interlocking.DANGER = DANGER

advtrains.interlocking.GENERIC_FREE = {
	main = -1,
	shunt = false,
	dst = false,
}

local function convert_aspect_if_necessary(asp)
	if type(asp.main) == "table" then
		local newasp = {} 
		if asp.main.free then
			newasp.main = asp.main.speed
		else
			newasp.main = 0
		end
		if asp.dst and asp.dst.free then
			newasp.dst = asp.dst.speed
		else
			newasp.dst = 0
		end
		newasp.proceed_as_main = asp.shunt.proceed_as_main
		newasp.shunt = asp.shunt.free
		-- Note: info table not transferred, it's not used right now
		return newasp
	end
	return asp
end

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
	asp = convert_aspect_if_necessary(asp)
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
	
	advtrains.invalidate_all_paths_ahead(ipos)
end

function advtrains.interlocking.signal_rc_handler(pos, node, player, itemstack, pointed_thing)
	local pname = player:get_player_name()
	local control = player:get_player_control()
	if control.aux1 then
		advtrains.interlocking.show_ip_form(pos, pname)
		return
	end
	
	local sigd = advtrains.interlocking.db.get_sigd_for_signal(pos)
	if sigd then
		advtrains.interlocking.show_signalling_form(sigd, pname)
	else
		local ndef = minetest.registered_nodes[node.name]
		if ndef.advtrains and ndef.advtrains.set_aspect then
			-- permit to set aspect manually
			local function callback(pname, aspect)
				advtrains.interlocking.signal_set_aspect(pos, aspect)
			end
			local isasp = ndef.advtrains.get_aspect(pos, node)
			
			advtrains.interlocking.show_signal_aspect_selector(
				pname,
				ndef.advtrains.supported_aspects,
				"Set aspect manually", callback,
				isasp)
		else
			--static signal - only IP
			advtrains.interlocking.show_ip_form(pos, pname)
		end
	end
end

-- Returns the aspect the signal at pos is supposed to show
function advtrains.interlocking.signal_get_supposed_aspect(pos)
	local sigd = advtrains.interlocking.db.get_sigd_for_signal(pos)
	if sigd then
		local tcbs = advtrains.interlocking.db.get_tcbs(sigd)
		if tcbs.aspect then
			return convert_aspect_if_necessary(tcbs.aspect)
		end
	end
	return DANGER;
end

-- Returns the actual aspect of the signal at position, as returned by the nodedef.
-- returns nil when there's no signal at the position
function advtrains.interlocking.signal_get_aspect(pos)
	local node=advtrains.ndb.get_node(pos)
	local ndef=minetest.registered_nodes[node.name]
	if ndef and ndef.advtrains and ndef.advtrains.get_aspect then
		local asp = ndef.advtrains.get_aspect(pos, node)
		if not asp then asp = DANGER end
		return convert_aspect_if_necessary(asp)
	end
	return nil
end

-- Returns the "supported_aspects" of the signal at position, as returned by the nodedef.
-- returns nil when there's no signal at the position
function advtrains.interlocking.signal_get_supported_aspects(pos)
	local node=advtrains.ndb.get_node(pos)
	local ndef=minetest.registered_nodes[node.name]
	if ndef and ndef.advtrains and ndef.advtrains.supported_aspects then
		local asp = ndef.advtrains.supported_aspects
		return asp
	end
	return nil
end

local players_assign_ip = {}

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

-- shows small info form for signal IP state/assignment
-- only_notset: show only if it is not set yet (used by signal tcb assignment)
function advtrains.interlocking.show_ip_form(pos, pname, only_notset)
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	local form = "size[7,5]label[0.5,0.5;Signal at "..minetest.pos_to_string(pos).."]"
	advtrains.interlocking.db.check_for_duplicate_ip(pos)
	local pts, connid = advtrains.interlocking.db.get_ip_by_signalpos(pos)
	if pts then
		form = form.."label[0.5,1.5;Influence point is set at "..pts.."/"..connid.."]"
		form = form.."button_exit[0.5,2.5;  5,1;set;Move]"
		form = form.."button_exit[0.5,3.5;  5,1;clear;Clear]"
		local ipos = minetest.string_to_pos(pts)
		ipmarker(ipos, connid)
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
	--advtrains.interlocking.db.clear_ip_by_signalpos(pos)
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


--== aspect selector ==--

local players_aspsel = {}

--[[
suppasp: "supported_aspects" table
purpose: form title string
callback: func(pname, aspect) called on form submit
isasp: aspect currently set
]]
function advtrains.interlocking.show_signal_aspect_selector(pname, p_suppasp, p_purpose, callback, isasp)
	local suppasp = p_suppasp or {
		main = {0, -1}, dst = {false}, shunt = false, info = {},
	}
	local purpose = p_purpose or ""
	
	local form = "size[7,7]label[0.5,0.5;Select Signal Aspect:]"
	form = form.."label[0.5,1;"..purpose.."]"
	
	form = form.."label[0.5,1.5;== Main Signal ==]"
	local selid = 1
	local entries = {}
	for idx, spv in ipairs(suppasp.main) do
		local entry
		if spv == 0 then
			entry = "Halt"
		elseif spv == -1 then
			entry = "Continue at maximum speed"
		elseif not spv then
			entry = "Continue\\, speed limit unchanged (no info)"
		else
			entry = "Continue at speed of "..spv				
		end
		-- hack: the crappy formspec system returns the label, not the index. save the index in it.
		entries[idx] = idx.."| "..entry
		if isasp and spv == (isasp.main or false) then
			selid = idx
		end
	end
	form = form.."dropdown[0.5,2;6;main;"..table.concat(entries, ",")..";"..selid.."]"

	
	form = form.."label[0.5,3;== Shunting ==]"
	if suppasp.shunt == nil then
		local st = 1
		if isasp and isasp.shunt then st=2 end
		form = form.."dropdown[0.5,3.5;6;shunt_free;---,allowed;"..st.."]"
	end

	form = form.."label[0.5,4.5;== Distant Signal ==]"
	local selid = 1
	local entries = {}
	for idx, spv in ipairs(suppasp.dst) do
		local entry
		if spv == 0 then
			entry = "Expect to stop at the next signal"
		elseif spv == -1 then
			entry = "Expect to pass the next signal at maximum speed"
		elseif not spv then
			entry = "No info"
		else
			entry = string.format("Expect to pass the next signal at speed of %d", spv)
		end
		entries[idx] = idx.."| "..entry
		if isasp and spv == (isasp.dst or false) then
			selid = idx
		end
	end
	form = form.."dropdown[0.5,5;6;dst;"..table.concat(entries, ",")..";"..selid.."]"

	form = form.."button_exit[0.5,6;5,1;save;Save signal aspect]"
	
	local token = advtrains.random_id()
	
	minetest.show_formspec(pname, "at_il_sigaspdia_"..token, form)
	
	minetest.after(1, function()
	players_aspsel[pname] = {
		suppasp = suppasp,
		callback = callback,
		token = token,
	}
	end)
end

local function usebool(sup, val, free)
	if sup == nil then
		return val==free
	else
		return sup
	end
end

-- other side of hack: extract the index
local function ddindex(val)
	return tonumber(string.match(val, "^(%d+)|"))
end

-- TODO use non-hacky way to parse outputs

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local psl = players_aspsel[pname]
	if psl then
		if formname == "at_il_sigaspdia_"..psl.token then
			if fields.save then
				local maini = ddindex(fields.main)
				if not maini then return end
				local dsti = ddindex(fields.dst)
				if not dsti then return end
				local asp = {
					main = psl.suppasp.main[maini],
					dst = psl.suppasp.dst[dsti],
					shunt = usebool(psl.suppasp.shunt, fields.shunt_free, "allowed"),
					info = {}
				}
				psl.callback(pname, asp)
			end
		else
			players_aspsel[pname] = nil
		end
	end
	
end)
