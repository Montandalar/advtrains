-- Track Circuit Breaks and Track Sections - Player interaction

local players_assign_tcb = {}
local players_assign_signal = {}
local players_link_ts = {}

local ildb = advtrains.interlocking.db
local ilrs = advtrains.interlocking.route

local lntrans = { "A", "B" }

local function sigd_to_string(sigd)
	return minetest.pos_to_string(sigd.p).." / "..lntrans[sigd.s]
end

minetest.register_node("advtrains_interlocking:tcb_node", {
	drawtype = "mesh",
	paramtype="light",
	paramtype2="facedir",
	walkable = true,
	selection_box = {
		type = "fixed",
		fixed = {-1/6, -1/2, -1/6, 1/6, 1/4, 1/6},
	},
	mesh = "at_il_tcb_node.obj",
	tiles = {"at_il_tcb_node.png"},
	description="Track Circuit Break",
	sunlight_propagates=true,
	groups = {
		cracky=3,
		not_blocking_trains=1,
		--save_in_at_nodedb=2,
		at_il_track_circuit_break = 1,
	},
	after_place_node = function(pos, node, player)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Unconfigured Track Circuit Break, right-click to assign.")
	end,
	on_rightclick = function(pos, node, player)
		local meta = minetest.get_meta(pos)
		local tcbpts = meta:get_string("tcb_pos")
		local pname = player:get_player_name()
		if tcbpts ~= "" then
			local tcbpos = minetest.string_to_pos(tcbpts)
			advtrains.interlocking.show_tcb_form(tcbpos, pname)
		else
			--unconfigured
			--TODO security
			minetest.chat_send_player(pname, "Configuring TCB: Please punch the rail you want to assign this TCB to.")
			
			players_assign_tcb[pname] = pos
		end	
	end,
	--on_punch = function(pos, node, player)
	--	local meta = minetest.get_meta(pos)
	--	local tcbpts = meta:get_string("tcb_pos")
	--	if tcbpts ~= "" then
	--		local tcbpos = minetest.string_to_pos(tcbpts)
	--		advtrains.interlocking.show_tcb_marker(tcbpos)
	--	end	
	--end,
	can_dig = function(pos, player)
		-- Those markers can only be dug when all adjacent TS's are set
		-- as EOI.
		local meta = minetest.get_meta(pos)
		local tcbpts = meta:get_string("tcb_pos")
		if tcbpts ~= "" then
			local tcbpos = minetest.string_to_pos(tcbpts)
			local tcb = ildb.get_tcb(tcbpos)
			if not tcb then return true end
			for connid=1,2 do
				if tcb[connid].ts_id then
					return false
				end
			end
		end	
		return true
	end,
	after_dig_node = function(pos, oldnode, oldmetadata, player)
		if not oldmetadata or not oldmetadata.fields then return end
		local tcbpts = oldmetadata.fields.tcb_pos
		if tcbpts ~= "" then
			local tcbpos = minetest.string_to_pos(tcbpts)
			ildb.remove_tcb(tcbpos)
		end
	end,
})

minetest.register_on_punchnode(function(pos, node, player, pointed_thing)
	local pname = player:get_player_name()
	-- TCB assignment
	local tcbnpos = players_assign_tcb[pname]
	if tcbnpos then
		if vector.distance(pos, tcbnpos)<=20 then
			local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
			if node_ok and #conns == 2 then
				local ok = ildb.create_tcb(pos)
				
				if not ok then
					minetest.chat_send_player(pname, "Configuring TCB: TCB already exists at this position. Aborted.")
				end
				
				ildb.sync_tcb_neighbors(pos, 1)
				ildb.sync_tcb_neighbors(pos, 2)
				
				local meta = minetest.get_meta(tcbnpos)
				meta:set_string("tcb_pos", minetest.pos_to_string(pos))
				meta:set_string("infotext", "TCB assigned to "..minetest.pos_to_string(pos))
				minetest.chat_send_player(pname, "Configuring TCB: Successfully configured TCB")
			else
				minetest.chat_send_player(pname, "Configuring TCB: This is not a normal two-connection rail! Aborted.")
			end
		else
			minetest.chat_send_player(pname, "Configuring TCB: Node is too far away. Aborted.")
		end
		players_assign_tcb[pname] = nil
	end
	
	-- Signal assignment
	local sigd = players_assign_signal[pname]
	if sigd then
		if vector.distance(pos, sigd.p)<=50 then
			local is_signal = minetest.get_item_group(node.name, "advtrains_signal") >= 2
			if is_signal then
				local tcbs = ildb.get_tcbs(sigd)
				if tcbs then
					tcbs.signal = pos
					tcbs.signal_name = "Signal at "..minetest.pos_to_string(sigd.p)
					tcbs.routes = {}
					ildb.set_sigd_for_signal(pos, sigd)
					minetest.chat_send_player(pname, "Configuring TCB: Successfully assigned signal.")
				else
					minetest.chat_send_player(pname, "Configuring TCB: Internal error, TCBS doesn't exist. Aborted.")
				end
			else
				minetest.chat_send_player(pname, "Configuring TCB: Not a compatible signal. Aborted.")
			end
		else
			minetest.chat_send_player(pname, "Configuring TCB: Node is too far away. Aborted.")
		end
		players_assign_signal[pname] = nil
	end
end)


-- TCB Form

local function mktcbformspec(tcbs, btnpref, offset, pname)
	local form = ""
	local ts
	if tcbs.ts_id then
		ts = ildb.get_ts(tcbs.ts_id)
	end
	if ts then
		form = form.."label[0.5,"..offset..";Side "..btnpref..": "..ts.name.."]"
		form = form.."button[0.5,"..(offset+0.5)..";5,1;"..btnpref.."_gotots;Show track section]"
		form = form.."button[0.5,"..(offset+1.5)..";2.5,1;"..btnpref.."_update;Update near TCBs]"
		form = form.."button[3  ,"..(offset+1.5)..";2.5,1;"..btnpref.."_remove;Remove from section]"
	else
		tcbs.ts_id = nil
		form = form.."label[0.5,"..offset..";Side "..btnpref..": ".."End of interlocking]"
		form = form.."button[0.5,"..(offset+0.5)..";5,1;"..btnpref.."_makeil;Create Interlocked Track Section]"
		if tcbs.section_free then
			form = form.."button[0.5,"..(offset+1.5)..";5,1;"..btnpref.."_setlocked;Section is free]"
		else
			form = form.."button[0.5,"..(offset+1.5)..";5,1;"..btnpref.."_setfree;Section is blocked]"		
		end
	end
	if tcbs.signal then
		form = form.."button[0.5,"..(offset+2.5)..";5,1;"..btnpref.."_sigdia;Signalling]"	
	else
		form = form.."button[0.5,"..(offset+2.5)..";5,1;"..btnpref.."_asnsig;Assign a signal]"
	end
	return form
end


function advtrains.interlocking.show_tcb_form(pos, pname)
	local tcb = ildb.get_tcb(pos)
	if not tcb then return end
	
	local form = "size[6,9] label[0.5,0.5;Track Circuit Break Configuration]"
	form = form .. mktcbformspec(tcb[1], "A", 1, pname)
	form = form .. mktcbformspec(tcb[2], "B", 5, pname)
	
	minetest.show_formspec(pname, "at_il_tcbconfig_"..minetest.pos_to_string(pos), form)
	advtrains.interlocking.show_tcb_marker(pos)
end

--helper: length of nil table is 0
local function nlen(t)
	if not t then return 0 end
	return #t
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local pts = string.match(formname, "^at_il_tcbconfig_(.+)$")
	local pos
	if pts then
		pos = minetest.string_to_pos(pts)
	end
	if pos and not fields.quit then
		local tcb = ildb.get_tcb(pos)
		if not tcb then return end
		local f_gotots = {fields.A_gotots, fields.B_gotots}
		local f_update = {fields.A_update, fields.B_update}
		local f_remove = {fields.A_remove, fields.B_remove}
		local f_makeil = {fields.A_makeil, fields.B_makeil}
		local f_setlocked = {fields.A_setlocked, fields.B_setlocked}
		local f_setfree = {fields.A_setfree, fields.B_setfree}
		local f_asnsig = {fields.A_asnsig, fields.B_asnsig}
		local f_sigdia = {fields.A_sigdia, fields.B_sigdia}
		
		for connid=1,2 do
			local tcbs = tcb[connid]
			if tcbs.ts_id then
				if f_gotots[connid] then
					advtrains.interlocking.show_ts_form(tcbs.ts_id, pname)
					return
				end
				if f_update[connid] then
					ildb.sync_tcb_neighbors(pos, connid)
				end
				if f_remove[connid] then
					ildb.remove_from_interlocking({p=pos, s=connid})
				end
			else
				if f_makeil[connid] then
					-- try sinc_tcb_neighbors first
					ildb.sync_tcb_neighbors(pos, connid)
					-- if that didn't work, create new section
					if not tcbs.ts_id then
						ildb.create_ts({p=pos, s=connid})
						ildb.sync_tcb_neighbors(pos, connid)
					end
				end
				-- non-interlocked
				if f_setfree[connid] then
					tcbs.section_free = true
				end
				if f_setlocked[connid] then
					tcbs.section_free = nil
				end
			end
			if f_asnsig[connid] and not tcbs.signal then
				minetest.chat_send_player(pname, "Configuring TCB: Please punch the signal to assign.")
				players_assign_signal[pname] = {p=pos, s=connid}
				minetest.close_formspec(pname, formname)
				return
			end
			if f_sigdia[connid] and tcbs.signal then
				advtrains.interlocking.show_signalling_form({p=pos, s=connid}, pname)
				return
			end

		end
		advtrains.interlocking.show_tcb_form(pos, pname)
	end

end)



-- TS Formspec

-- textlist selection temporary storage
local ts_pselidx = {}

function advtrains.interlocking.show_ts_form(ts_id, pname, sel_tcb)
	local ts = ildb.get_ts(ts_id)
	if not ts_id then return end
	
	local form = "size[10,10]label[0.5,0.5;Track Section Detail - "..ts_id.."]"
	form = form.."field[0.8,2;5.2,1;name;Section name;"..ts.name.."]"
	form = form.."button[5.5,1.7;1,1;setname;Set]"
	local hint
	
	local strtab = {}
	for idx, sigd in ipairs(ts.tc_breaks) do
		strtab[#strtab+1] = minetest.formspec_escape(sigd_to_string(sigd))
		advtrains.interlocking.show_tcb_marker(sigd.p)
	end
	
	form = form.."textlist[0.5,3;5,3;tcblist;"..table.concat(strtab, ",").."]"
	if players_link_ts[pname] then
		local other_id = players_link_ts[pname]
		local other_ts = ildb.get_ts(other_id)
		if other_ts then
			form = form.."button[5.5,3;3.5,1;mklink;Join with "..other_ts.name.."]"
			form = form.."button[9  ,3;0.5,1;cancellink;X]"
		end
	else
		form = form.."button[5.5,3;4,1;link;Join into other section]"
		hint = 1
	end
	form = form.."button[5.5,4;4,1;dissolve;Dissolve Section]"
	form = form.."tooltip[dissolve;This will remove the track section and set all its end points to End Of Interlocking]"
	if sel_tcb then
		form = form.."button[5.5,5;4,1;del_tcb;Unlink selected TCB]"
		hint = 2
	end
	
	-- occupying trains
	if ts.trains and #ts.trains>0 then
		form = form.."label[0.5,6.1;Trains on this section:]"
		form = form.."textlist[0.5,6.7;3,2;trnlist;"..table.concat(ts.trains, ",").."]"
	else
		form = form.."label[0.5,6.1;No trains on this section.]"
	end
	
	if hint == 1 then
		form = form.."label[0.5,0.75;Use the 'Join' button to designate rail crosses and link not listed far-away TCBs]"
	elseif hint == 2 then
		form = form.."label[0.5,0.75;Unlinking a TCB will set it to non-interlocked mode.]"
		--form = form.."label[0.5,1;Trying to unlink a TCB directly connected to this track will not work.]"
	end
	
	ts_pselidx[pname]=sel_tcb
	minetest.show_formspec(pname, "at_il_tsconfig_"..ts_id, form)
	
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	-- independent of the formspec, clear this whenever some formspec event happens
	local tpsi = ts_pselidx[pname]
	ts_pselidx[pname] = nil
	
	local ts_id = string.match(formname, "^at_il_tsconfig_(.+)$")
	if ts_id and not fields.quit then
		local ts = ildb.get_ts(ts_id)
		if not ts then return end
		
		local sel_tcb
		if fields.tcblist then
			local tev = minetest.explode_textlist_event(fields.tcblist)
			sel_tcb = tev.index
			ts_pselidx[pname] = sel_tcb
		elseif tpsi then
			sel_tcb = tpsi
		end
		
		if players_link_ts[pname] then
			if fields.cancellink then
				players_link_ts[pname] = nil
			elseif fields.mklink then
				ildb.link_track_sections(players_link_ts[pname], ts_id)
				players_link_ts[pname] = nil
			end
		end
		
		if fields.del_tcb and sel_tcb and sel_tcb > 0 and sel_tcb <= #ts.tc_breaks then
			ildb.remove_from_interlocking(ts.tc_breaks[sel_tcb])
			sel_tcb = nil
		end
		
		if fields.link then
			players_link_ts[pname] = ts_id
		end
		if fields.dissolve then
			ildb.dissolve_ts(ts_id)
			minetest.close_formspec(pname, formname)
			return
		end
		
		if fields.setname then
			ts.name = fields.name
			if ts.name == "" then
				ts.name = "Section "..ts_id
			end
		end
		advtrains.interlocking.show_ts_form(ts_id, pname, sel_tcb)
	end
end)

-- TCB marker entities

-- table with objectRefs
local markerent = {}

minetest.register_entity("advtrains_interlocking:tcbmarker", {
	visual = "mesh",
	mesh = "trackplane.b3d",
	textures = {"at_il_tcb_marker.png"},
	collisionbox = {-1,-0.5,-1, 1,-0.4,1},
	visual_size = {x=10, y=10},
	on_punch = function(self)
		self.object:remove()
	end,
	on_rightclick = function(self, player)
		if self.tcbpos and player then
			advtrains.interlocking.show_tcb_form(self.tcbpos, player:get_player_name())
		end
	end,
	get_staticdata = function() return "STATIC" end,
	on_activate = function(self, sdata) if sdata=="STATIC" then self.object:remove() end end,
	static_save = false,
})

function advtrains.interlocking.show_tcb_marker(pos)
	--atdebug("showing tcb marker",pos)
	local tcb = ildb.get_tcb(pos)
	if not tcb then return end
	local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
	if not node_ok then return end
	local yaw = advtrains.conn_angle_median(conns[2].c, conns[1].c)
	
	local itex = {}
	for connid=1,2 do
		local tcbs = tcb[connid]
		local ts
		if tcbs.ts_id then
			ts = ildb.get_ts(tcbs.ts_id)
		end
		if ts then
			itex[connid] = ts.name
		else
			itex[connid] = "--EOI--"
		end
	end
	
	local pts = advtrains.roundfloorpts(pos)
	if markerent[pts] then
		markerent[pts]:remove()
	end
	
	local obj = minetest.add_entity(pos, "advtrains_interlocking:tcbmarker")
	if not obj then return end
	obj:set_yaw(yaw)
	obj:set_properties({
		infotext = "A = "..itex[1].."\nB = "..itex[2]
	})
	local le = obj:get_luaentity()
	if le then le.tcbpos = pos end
	
	markerent[pts] = obj
end

-- Signalling formspec - set routes a.s.o

-- textlist selection temporary storage
local sig_pselidx = {}

function advtrains.interlocking.show_signalling_form(sigd, pname, sel_rte)
	local tcbs = ildb.get_tcbs(sigd)
	
	if not tcbs.signal then return end
	if not tcbs.signal_name then tcbs.signal_name = "Signal at "..minetest.pos_to_string(sigd.p) end
	if not tcbs.routes then tcbs.routes = {} end
	
	local form = "size[7,9]label[0.5,0.5;Signal at "..minetest.pos_to_string(sigd.p).."]"
	form = form.."field[0.8,1.5;5.2,1;name;Signal name;"..tcbs.signal_name.."]"
	form = form.."button[5.5,1.2;1,1;setname;Set]"
	
	if tcbs.routeset then
		local rte = tcbs.routes[tcbs.routeset]
		form = form.."label[0.5,2.5;A route is requested from this signal:]"
		form = form.."label[0.5,3.0;"..rte.name.."]"
		if tcbs.route_committed then
			form = form.."label[0.5,3.5;Route has been set.]"
		else
			form = form.."label[0.5,3.5;Waiting for route to be set...]"
			if tcbs.route_rsn then
				form = form.."label[0.5,4;"..tcbs.route_rsn.."]"
			end
		end
		
		form = form.."button[0.5,6;  5,1;cancelroute;Cancel Route]"
	else
		local strtab = {}
		for idx, route in ipairs(tcbs.routes) do
			strtab[#strtab+1] = minetest.formspec_escape(route.name)
		end
		form = form.."label[0.5,2.5;Routes:]"
		form = form.."textlist[0.5,3;5,3;rtelist;"..table.concat(strtab, ",").."]"
		if sel_rte then
			form = form.."button[0.5,6;  5,1;setroute;Set Route]"
			form = form.."button[0.5,7;2,1;dsproute;Show]"
			form = form.."button[2.5,7;1,1;delroute;Delete]"
			form = form.."button[3.5,7;2,1;renroute;Rename]"
		end
		form = form.."button[0.5,8;2.5,1;newroute;New Route]"
		form = form.."button[  3,8;2.5,1;unassign;Unassign Signal]"
		
	end	
	sig_pselidx[pname] = sel_rte
	minetest.show_formspec(pname, "at_il_signalling_"..minetest.pos_to_string(sigd.p).."_"..sigd.s, form)
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	
	-- independent of the formspec, clear this whenever some formspec event happens
	local tpsi = sig_pselidx[pname]
	sig_pselidx[pname] = nil
	
	local pts, connids = string.match(formname, "^at_il_signalling_([^_]+)_(%d)$")
	local pos, connid
	if pts then
		pos = minetest.string_to_pos(pts)
		connid = tonumber(connids)
		if not connid or connid<1 or connid>2 then return end
	end
	if pos and connid and not fields.quit then
		local sigd = {p=pos, s=connid}
		local tcbs = ildb.get_tcbs(sigd)
		if not tcbs then return end
		
		local sel_rte
		if fields.rtelist then
			local tev = minetest.explode_textlist_event(fields.rtelist)
			sel_rte = tev.index
		elseif tpsi then
			sel_rte = tpsi
		end
		if fields.setname and fields.name then
			tcbs.signal_name = fields.name
		end
		if tcbs.routeset and fields.cancelroute then
			-- if route committed, cancel route ts info
			
			ilrs.update_route(sigd, tcbs, nil, true)
		end
		if not tcbs.routeset then
			if fields.newroute then
				advtrains.interlocking.init_route_prog(pname, sigd)
				minetest.close_formspec(pname, formname)
				return
			end
			if sel_rte and tcbs.routes[sel_rte] then
				if fields.setroute then
					ilrs.update_route(sigd, tcbs, sel_rte)
					atwarn("routeset:",tcbs.routeset," committed:",tcbs.route_committed)
					atwarn(tcbs.route_rsn)
				end
				if fields.dsproute then
					local t = os.clock()
					advtrains.interlocking.visualize_route(sigd, tcbs.routes[sel_rte], "disp_"..t)
					minetest.after(10, function() advtrains.interlocking.clear_visu_context("disp_"..t) end)
				end
				if fields.renroute then
					local rte = tcbs.routes[sel_rte]
					minetest.show_formspec(pname, formname.."_renroute_"..sel_rte, "field[name;Enter new route name;"..rte.name.."]")
					return
				end
				if fields.delroute then
					table.remove(tcbs.routes, sel_rte)
					sel_rte = nil
				end
			end
		end
		
		advtrains.interlocking.show_signalling_form(sigd, pname, sel_rte)
		return
	end
	
	-- rename route
	local rind, rte_id
	pts, connids, rind = string.match(formname, "^at_il_signalling_([^_]+)_(%d)_renroute_(%d+)$")
	if pts then
		pos = minetest.string_to_pos(pts)
		connid = tonumber(connids)
		rte_id = tonumber(rind)
		if not connid or connid<1 or connid>2 then return end
	end
	if pos and connid and rind and fields.name then
		local sigd = {p=pos, s=connid}
		local tcbs = ildb.get_tcbs(sigd)
		if tcbs.routes[rte_id] then
			tcbs.routes[rte_id].name = fields.name
			advtrains.interlocking.show_signalling_form(sigd, pname)
		end
	end
end)
