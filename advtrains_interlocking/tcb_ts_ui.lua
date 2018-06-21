-- Track Circuit Breaks and Track Sections - Player interaction

local players_assign_tcb = {}
local players_link_ts = {}

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
		fixed = {-1/4, -1/2, -1/4, 1/4, 1/2, 1/4},
	},
	mesh = "at_il_tcb_node.obj",
	tiles = {"at_il_tcb_node.png"},
	description="Track Circuit Break",
	sunlight_propagates=true,
	groups = {
		cracky=3,
		not_blocking_trains=1,
		--save_in_at_nodedb=2,
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
	on_punch = function(pos, node, player)
		local meta = minetest.get_meta(pos)
		atwarn("Would show tcb marker.")
			-- TODO TCB-Marker anzeigen
	end,
})

minetest.register_on_punchnode(function(pos, node, player, pointed_thing)
	local pname = player:get_player_name()
	local tcbnpos = players_assign_tcb[pname]
	if tcbnpos then
		if vector.distance(pos, tcbnpos)<=20 then
			local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
			if node_ok and #conns == 2 then
				advtrains.interlocking.db.create_tcb(pos)
				
				advtrains.interlocking.db.sync_tcb_neighbors(pos, 1)
				advtrains.interlocking.db.sync_tcb_neighbors(pos, 2)
				
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
end)


-- TCB Form

local function mktcbformspec(tcbs, btnpref, offset, pname)
	local form = ""
	local ts
	if tcbs.ts_id then
		ts = advtrains.interlocking.db.get_ts(tcbs.ts_id)
	end
	if ts then
		form = form.."label[0.5,"..offset..";Side "..btnpref..": "..ts.name.."]"
		form = form.."button[0.5,"..(offset+1)..";5,1;"..btnpref.."_gotots;Show track section]"
		form = form.."button[0.5,"..(offset+2)..";2.5,1;"..btnpref.."_update;Update near TCBs]"
		form = form.."button[3  ,"..(offset+2)..";2.5,1;"..btnpref.."_remove;Remove from section]"
	else
		tcbs.ts_id = nil
		form = form.."label[0.5,"..offset..";Side "..btnpref..": ".."End of interlocking]"
		form = form.."button[0.5,"..(offset+1)..";5,1;"..btnpref.."_makeil;Create Interlocked Track Section]"
		if tcbs.section_free then
			form = form.."button[0.5,"..(offset+2)..";5,1;"..btnpref.."_setlocked;Section is free]"
		else
			form = form.."button[0.5,"..(offset+2)..";5,1;"..btnpref.."_setfree;Section is blocked]"		
		end
	end
	return form
end


function advtrains.interlocking.show_tcb_form(pos, pname)
	local tcb = advtrains.interlocking.db.get_tcb(pos)
	if not tcb then return end
	
	local form = "size[6,7] label[0.5,0.5;Track Circuit Break Configuration]"
	form = form .. mktcbformspec(tcb[1], "A", 1, pname)
	form = form .. mktcbformspec(tcb[2], "B", 4, pname)
	
	minetest.show_formspec(pname, "at_il_tcbconfig_"..minetest.pos_to_string(pos), form)
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
		local tcb = advtrains.interlocking.db.get_tcb(pos)
		if not tcb then return end
		local f_gotots = {fields.A_gotots, fields.B_gotots}
		local f_update = {fields.A_update, fields.B_update}
		local f_remove = {fields.A_remove, fields.B_remove}
		local f_makeil = {fields.A_makeil, fields.B_makeil}
		local f_setlocked = {fields.A_setlocked, fields.B_setlocked}
		local f_setfree = {fields.A_setfree, fields.B_setfree}
		
		for connid=1,2 do
			local tcbs = tcb[connid]
			if tcbs.ts_id then
				if f_gotots[connid] then
					advtrains.interlocking.show_ts_form(tcbs.ts_id, pname)
					return
				end
				if f_update[connid] then
					advtrains.interlocking.db.sync_tcb_neighbors(pos, connid)
				end
				if f_remove[connid] then
					advtrains.interlocking.db.remove_from_interlocking({p=pos, s=connid})
				end
			else
				if f_makeil[connid] then
					advtrains.interlocking.db.create_ts({p=pos, s=connid})
					advtrains.interlocking.db.sync_tcb_neighbors(pos, connid)
				end
				-- non-interlocked
				if f_setfree[connid] then
					tcbs.section_free = true
				end
				if f_setlocked[connid] then
					tcbs.section_free = nil
				end
			end
		end
		advtrains.interlocking.show_tcb_form(pos, pname)
	end

end)



-- TS Formspec

function advtrains.interlocking.show_ts_form(ts_id, pname, sel_tcb)
	local ts = advtrains.interlocking.db.get_ts(ts_id)
	if not ts_id then return end
	
	local form = "size[10,10]label[0.5,0.5;Track Section Detail - "..ts_id.."]"
	form = form.."field[0.8,2;5.2,1;name;Section name;"..ts.name.."]"
	form = form.."button[5.5,1.7;1,1;setname;Set]"
	local hint
	
	local strtab = {}
	for idx, sigd in ipairs(ts.tc_breaks) do
		strtab[#strtab+1] = minetest.formspec_escape(sigd_to_string(sigd))
	end
	
	form = form.."textlist[0.5,3;5,3;tcblist;"..table.concat(strtab, ",").."]"
	if players_link_ts[pname] then
		local other_id = players_link_ts[pname]
		local other_ts = advtrains.interlocking.db.get_ts(other_id)
		if other_ts then
			form = form.."button[5.5,3.5;3.5,1;mklink;Join with "..other_ts.name.."]"
			form = form.."button[9  ,3.5;0.5,1;cancellink;X]"
		end
	else
		form = form.."button[5.5,3.5;4,1;link;Join into other section]"
		hint = 1
	end
	if sel_tcb then
		form = form.."button[5.5,4.5;4,1;del_tcb;Remove selected TCB]"
		hint = 2
	end
	if hint == 1 then
		form = form.."label[0.5,0.75;Use the 'Join' button to designate rail crosses and link not listed far-away TCBs]"
	elseif hint == 2 then
		form = form.."label[0.5,0.75;Removing a TCB will set it to non-interlocked mode.]"
		form = form.."label[0.5,1;Trying to remove a TCB directly connected to this track will not work.]"
	end
	
	minetest.show_formspec(pname, "at_il_tsconfig_"..ts_id, form)
	
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local ts_id = string.match(formname, "^at_il_tsconfig_(.+)$")
	if ts_id and not fields.quit then
		local ts = advtrains.interlocking.db.get_ts(ts_id)
		if not ts then return end
		
		local sel_tcb
		if fields.tcblist then
			local tev = minetest.explode_textlist_event(fields.tcblist)
			sel_tcb = tev.index
		end
		
		if players_link_ts[pname] then
			if fields.cancellink then
				players_link_ts[pname] = nil
			elseif fields.mklink then
				advtrains.interlocking.db.link_track_sections(players_link_ts[pname], ts_id)
			end
		end
		
		if fields.del_tcb and sel_tcb and sel_tcb > 0 and sel_tcb <= #ts.tc_breaks then
			advtrains.interlocking.db.remove_from_interlocking(ts.tc_breaks[sel_tcb])
		end
		
		if fields.link then
			players_link_ts[pname] = ts_id
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


