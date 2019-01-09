-- route_ui.lua
-- User interface for showing and editing routes

local atil = advtrains.interlocking
local ildb = atil.db

-- TODO duplicate
local lntrans = { "A", "B" }
local function sigd_to_string(sigd)
	return minetest.pos_to_string(sigd.p).." / "..lntrans[sigd.s]
end

-- The ARS data are saved in a table format, but are entered in text format. Utility functions to transform between both.
local function ars_to_text(arstab)
	if not arstab then
		return ""
	end
	
	local txt = {}
	
	for i, arsent in ipairs(arstab) do
		if arsent.ln then
			txt[#txt+1] = "LN "..arsent.ln
		elseif arsent.rc then
			txt[#txt+1] = "RC "..arsent.rc
		elseif arsent.c then
			txt[#txt+1] = "#"..arsent.c
		end
	end
	
	if arstab.default then
		return "*\n" .. table.concat(txt, "\n")
	end
	return table.concat(txt, "\n")
end

local function text_to_ars(t)
	if t=="" then
		return nil
	elseif t=="*" then
		return {default=true}
	end
	local arstab = {}
	for line in string.gmatch(t, "[^\r\n]+") do
		if line=="*" then
			arstab.default = true
		else
			local c, v = string.match(line, "^(..)%s(.*)$")
			if c and v then
				local tt=string.upper(c)
				if tt=="LN" then
					arstab[#arstab+1] = {ln=v}
				elseif tt=="RC" then
					arstab[#arstab+1] = {rc=v}
				end
			else
				local ct = string.match(line, "^#(.*)$")
				if ct then arstab[#arstab+1] = {c = ct} end
			end
		end
	end
	return arstab
end



function atil.show_route_edit_form(pname, sigd, routeid)

	if not minetest.check_player_privs(pname, {train_operator=true, interlocking=true}) then
		minetest.chat_send_player(pname, "Insufficient privileges to use this!")
		return
	end
	
	local tcbs = atil.db.get_tcbs(sigd)
	if not tcbs then return end
	local route = tcbs.routes[routeid]
	if not route then return end
	
	local form = "size[9,10]label[0.5,0.2;Route overview]"
	form = form.."field[0.8,1.2;5.2,1;name;Route name;"..route.name.."]"
	form = form.."button[5.5,0.9;1,1;setname;Set]"
	
	-- construct textlist for route information
	local tab = {}
	local function itab(t)
		tab[#tab+1] = string.gsub(t, ",", " ")
	end
	itab("TCB "..sigd_to_string(sigd).." ("..tcbs.signal_name..") Route #"..routeid)
	
	-- this code is partially copy-pasted from routesetting.lua
	-- we start at the tc designated by signal
	local c_sigd = sigd
	local i = 1
	local c_tcbs, c_ts_id, c_ts, c_rseg, c_lckp
	while c_sigd and i<=#route do
		c_tcbs = ildb.get_tcbs(c_sigd)
		c_ts_id = c_tcbs.ts_id
		if not c_ts_id then
			itab("-!- No track section adjacent to "..sigd_to_string(c_sigd)..". Please reconfigure route!")
		end
		c_ts = ildb.get_ts(c_ts_id)
		
		c_rseg = route[i]
		c_lckp = {}
		
		itab(""..i.." Entry "..sigd_to_string(c_sigd).." -> Sec. "..c_ts.name.." -> Exit "..(c_rseg.next and sigd_to_string(c_rseg.next) or "END"))
		
		for pts, state in pairs(c_rseg.locks) do
			
			local pos = minetest.string_to_pos(pts)
			itab("  Lock: "..pts.." -> "..state)
			if not advtrains.is_passive(pos) then
				itab("-!- No passive component at "..pts..". Please reconfigure route!")
			end
		end
		-- advance
		c_sigd = c_rseg.next
		i = i + 1
	end
	if c_sigd then
		local e_tcbs = ildb.get_tcbs(c_sigd)
		itab("Route end: "..sigd_to_string(c_sigd).." ("..(e_tcbs.signal_name or "-")..")")
	else
		itab("Route ends on dead-end")
	end
	
	form = form.."textlist[0.5,2;7,4;rtelog;"..table.concat(tab, ",").."]"
	
	form = form.."button[0.5,6;2,1;back;<<< Back to signal]"
	form = form.."button[3.5,6;2,1;aspect;Signal Aspect]"
	form = form.."button[5.5,6;2,1;delete;Delete Route]"
	
	atdebug(route.ars)
	form = form.."textarea[1,7.3;5.2,3;ars;ARS Rule List;"..ars_to_text(route.ars).."]"
	form = form.."button[6,7.7;1,1;savears;Save]"
	
	minetest.show_formspec(pname, "at_il_routeedit_"..minetest.pos_to_string(sigd.p).."_"..sigd.s.."_"..routeid, form)

end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, {train_operator=true, interlocking=true}) then
		return
	end
	
	local pts, connids, routeids = string.match(formname, "^at_il_routeedit_([^_]+)_(%d)_(%d+)$")
	local pos, connid, routeid
	if pts then
		pos = minetest.string_to_pos(pts)
		connid = tonumber(connids)
		routeid = tonumber(routeids)
		if not connid or connid<1 or connid>2 then return end
		if not routeid then return end
	end
	if pos and connid and routeid and not fields.quit then
		local sigd = {p=pos, s=connid}
		local tcbs = ildb.get_tcbs(sigd)
		if not tcbs then return end
		local route = tcbs.routes[routeid]
		if not route then return end
		
		if fields.setname and fields.name then
			route.name = fields.name
		end
		
		if fields.aspect then
			local suppasp = advtrains.interlocking.signal_get_supported_aspects(tcbs.signal)
			
			local callback = function(pname, asp)
				route.aspect = asp
				advtrains.interlocking.show_route_edit_form(pname, sigd, routeid)
			end
			
			advtrains.interlocking.show_signal_aspect_selector(pname, suppasp, route.name, callback, rte.aspect)
			return
		end
		if fields.delete then
			-- if something set the route in the meantime, make sure this doesn't break.
			atil.route.update_route(sigd, tcbs, nil, true)
			table.remove(tcbs.routes, routeid)
			advtrains.interlocking.show_signalling_form(sigd, pname)
		end
		
		if fields.ars and fields.savears then
			route.ars = text_to_ars(fields.ars)
			atdebug(route.ars)
		end
		
		if fields.back then
			advtrains.interlocking.show_signalling_form(sigd, pname)
		end
		
	end
end)
