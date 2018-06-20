-- Track Circuit Breaks - Player interaction

local players_assign_tcb = {}
local players_addfar_tcb = {}

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
				
				advtrains.interlocking.db.update_tcb_neighbors(pos, 1)
				advtrains.interlocking.db.update_tcb_neighbors(pos, 2)
				
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


local function mkformspec(tcbs, btnpref, offset, pname)
	local form = "label[0.5,"..offset..";Side "..btnpref..": "..(tcbs.end_of_interlocking and "End of interlocking" or "Track Circuit").."]"
	if tcbs.end_of_interlocking then
		form = form.."button[0.5,"..(offset+1)..";3,1;"..btnpref.."_clearadj;Activate Interlocking]"
		if tcbs.section_free then
			form = form.."button[4.5,"..(offset+1)..";3,1;"..btnpref.."_setlocked;Section is free]"
		else
			form = form.."button[4.5,"..(offset+1)..";3,1;"..btnpref.."_setfree;Section is blocked]"		
		end
	else
		local strtab = {}
		for idx, sigd in ipairs(tcbs.adjacent) do
			strtab[idx] = minetest.formspec_escape(sigd_to_string(sigd))
		end
		form = form.."textlist[0.5,"..(offset+1)..";5,3;"..btnpref.."_adjlist;"..table.concat(strtab, ",").."]"
		if players_addfar_tcb[pname] then
			local sigd = players_addfar_tcb[pname]
			form = form.."button[5.5,"..(offset+2)..";2.5,1;"..btnpref.."_addadj;Link TCB to "..sigd_to_string(sigd).."]"
			form = form.."button[8,"..(offset+2)..";0.5,1;"..btnpref.."_canceladdadj;X]"
		else
			form = form.."button[5.5,"..(offset+2)..";3,1;"..btnpref.."_addadj;Add far TCB]"
		end
		form = form.."button[5.5,"..(offset+1)..";3,1;"..btnpref.."_clearadj;Clear&Update]"
		form = form.."button[5.5,"..(offset+3)..";3,1;"..btnpref.."_mknonint;Make non-interlocked]"
		if tcbs.incomplete then
			form = form.."label[0.5,"..(offset+0.5)..";Warning: You possibly need to add TCBs manually!]"
		end
	end
	return form
end



function advtrains.interlocking.show_tcb_form(pos, pname)
	local tcb = advtrains.interlocking.db.get_tcb(pos)
	if not tcb then return end
	
	local form = "size[10,10] label[0.5,0.5;Track Circuit Break Configuration]"
	form = form .. mkformspec(tcb[1], "A", 1, pname)
	form = form .. mkformspec(tcb[2], "B", 6, pname)
	
	minetest.show_formspec(pname, "at_il_tcbconfig_"..minetest.pos_to_string(pos), form)
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
		local f_clearadj = {fields.A_clearadj, fields.B_clearadj}
		local f_addadj = {fields.A_addadj, fields.B_addadj}
		local f_canceladdadj = {fields.A_canceladdadj, fields.B_canceladdadj}
		local f_setlocked = {fields.A_setlocked, fields.B_setlocked}
		local f_setfree = {fields.A_setfree, fields.B_setfree}
		local f_mknonint = {fields.A_mknonint, fields.B_mknonint}
		
		for connid=1,2 do
			if f_clearadj[connid] then
				advtrains.interlocking.db.update_tcb_neighbors(pos, connid)
			end
			if f_mknonint[connid] then
				--TODO: remove this from the other tcb's
				tcb[connid].end_of_interlocking = true
			end
			if f_addadj[connid] then
				if players_addfar_tcb[pname] then
					local sigd = players_addfar_tcb[pname]
					advtrains.interlocking.db.add_adjacent(tcb[connid], pos, connid, sigd)
					players_addfar_tcb[pname] = nil
				else
					players_addfar_tcb[pname] = {p = pos, s = connid}
				end
			end
			if f_canceladdadj[connid] then
				players_addfar_tcb[pname] = nil
			end
			if f_setfree[connid] then
				tcb[connid].section_free = true
			end
			if f_setlocked[connid] then
				tcb[connid].section_free = nil
			end
		end
		advtrains.interlocking.show_tcb_form(pos, pname)
	end

end)





