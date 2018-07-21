-- Route programming system

--[[
Progamming routes:
1. Select "program new route" in the signalling dialog
-> route_start marker will appear to designate route-program mode
2. Do those actions in any order:
A. punch a TCB marker node to proceed route along this TCB. This will only work if
	this is actually a TCB bordering the current TS, and will place a
	route_set marker and shift to the next TS
B. right-click a turnout to switch it (no impact to route programming
C. punch a turnout (or some other passive component) to fix its state (toggle)
	for the route. A sprite telling "Route Fix" will show that fact.
3. To complete route setting, use the chat command '/at_program_route <route name>'.
	The last punched TCB will get a 'route end' marker
	The end of a route should be at another signal facing the same direction as the entrance signal,
	however this is not enforced and left up to the signal engineer (the programmer)
	
The route visualization will also be used to visualize routes after they have been programmed.
]]--


-- table with objectRefs
local markerent = {}

minetest.register_entity("advtrains_interlocking:routemarker", {
	visual = "mesh",
	mesh = "trackplane.b3d",
	textures = {"at_il_route_set.png"},
	collisionbox = {-1,-0.5,-1, 1,-0.4,1},
	visual_size = {x=10, y=10},
	on_punch = function(self)
		self.object:remove()
	end,
	get_staticdata = function() return "STATIC" end,
	on_activate = function(self, sdata) if sdata=="STATIC" then self.object:remove() end end,
	static_save = false,
})


-- Spawn or update a route marker entity
-- pos: position where this is going to be
-- key: something unique to determine which entity to remove if this was set before
-- img: texture
local function routemarker(context, pos, key, img, yaw, itex)
	if not markerent[context] then
		markerent[context] = {}
	end
	if markerent[context][key] then
		markerent[context][key]:remove()
	end
	
	local obj = minetest.add_entity(vector.add(pos, {x=0, y=0.3, z=0}), "advtrains_interlocking:routemarker")
	if not obj then return end
	obj:set_yaw(yaw)
	obj:set_properties({
		infotext = itex,
		textures = {img},
	})
	
	markerent[context][key] = obj
end

minetest.register_entity("advtrains_interlocking:routesprite", {
	visual = "sprite",
	textures = {"at_il_turnout_free.png"},
	collisionbox = {-0.2,-0.2,-0.2, 0.2,0.2,0.2},
	visual_size = {x=1, y=1},
	on_punch = function(self)
		if self.callback then
			self.callback()
		end
		self.object:remove()
	end,
	get_staticdata = function() return "STATIC" end,
	on_activate = function(self, sdata) if sdata=="STATIC" then self.object:remove() end end,
	static_save = false,
})


-- Spawn or update a route sprite entity
-- pos: position where this is going to be
-- key: something unique to determine which entity to remove if this was set before
-- img: texture
local function routesprite(context, pos, key, img, itex, callback)
	if not markerent[context] then
		markerent[context] = {}
	end
	if markerent[context][key] then
		markerent[context][key]:remove()
	end
	
	local obj = minetest.add_entity(vector.add(pos, {x=0, y=0, z=0}), "advtrains_interlocking:routesprite")
	if not obj then return end
	obj:set_properties({
		infotext = itex,
		textures = {img},
	})
	
	if callback then
		obj:get_luaentity().callback = callback
	end
	
	markerent[context][key] = obj
end

--[[
Route definition:
route = {
	name = <string>
	[n] = {
		next = <sigd>, -- of the next (note: next) TCB on the route
		locks = {<pts> = "state"} -- route locks of this route segment
	}
}
The first item in the TCB path (namely i=0) is always the start signal of this route,
so this is left out.
All subsequent entries, starting from 1, contain:
- all route locks of the segment on TS between the (i-1). and the i. TCB
- the next TCB signal describer in proceeding direction of the route.

]]--

local function chat(pname, message)
	minetest.chat_send_player(pname, "[Route programming] "..message)
end
local function clear_lock(locks, pname, pts)
	locks[pts] = nil
	chat(pname, pts.." is no longer affected when this route is set.")
end

function advtrains.interlocking.clear_visu_context(context)
	if not markerent[context] then return end
	for key, obj in pairs(markerent[context]) do
		obj:remove()
	end
	markerent[context] = nil
end

-- visualize route. 'context' is a string that identifies the context of this visualization
-- e.g. prog_<player> or vis_<pts> for later visualizations
-- last 2 parameters are only to be used in the context of route programming!
function advtrains.interlocking.visualize_route(origin, route, context, tmp_lcks, pname)
	advtrains.interlocking.clear_visu_context(context)
	
	local oyaw = 0
	local onode_ok, oconns, orhe = advtrains.get_rail_info_at(origin.p, advtrains.all_tracktypes)
	if onode_ok then
		oyaw = advtrains.dir_to_angle(oconns[origin.s].c)
	end
	routemarker(context, origin.p, "rte_origin", "at_il_route_start.png", oyaw, route.name)
	
	for k,v in ipairs(route) do
		local sigd = v.next
		local yaw = 0
		local node_ok, conns, rhe = advtrains.get_rail_info_at(sigd.p, advtrains.all_tracktypes)
		if node_ok then
			yaw = advtrains.dir_to_angle(conns[sigd.s].c)
		end
		local img = "at_il_route_set.png"
		if k == #route then img = "at_il_route_end.png" end
		routemarker(context, sigd.p, "rte"..k, img, yaw, route.name.." #"..k)
		for pts, state in pairs(v.locks) do
			local pos = minetest.string_to_pos(pts)
			routesprite(context, pos, "fix"..k..pts, "at_il_route_lock.png", "Fixed in state '"..state.."' by route "..route.name.." until segment #"..k.." is freed.")
		end
	end
	if tmp_lcks then
		for pts, state in pairs(tmp_lcks) do
			local pos = minetest.string_to_pos(pts)
			routesprite(context, pos, "fixp"..pts, "at_il_route_lock_edit.png", "Fixed in state '"..state.."' by route "..route.name.." (punch to unfix)",
				function() clear_lock(tmp_lcks, pname, pts) end)
		end
	end
end


local player_rte_prog = {}

function advtrains.interlocking.init_route_prog(pname, sigd)
	player_rte_prog[pname] = {
		origin = sigd,
		route = {
			name = "PROG["..pname.."]",
		},
		tmp_lcks = {},
	}
	advtrains.interlocking.visualize_route(sigd, player_rte_prog[pname].route, "prog_"..pname, player_rte_prog[pname].tmp_lcks, pname)
	minetest.chat_send_player(pname, "Route programming mode active. Punch TCBs to add route segments, punch turnouts to lock them.")
	minetest.chat_send_player(pname, "Type /at_rp_set <name> when you are done, /at_rp_discard to cancel route programming")
end

local function get_last_route_item(origin, route)
	if #route == 0 then
		return origin
	end
	return route[#route].next
end

local function otherside(s)
	if s==1 then return 2 else return 1 end
end

-- Central route programming punch callback
minetest.register_on_punchnode(function(pos, node, player, pointed_thing)
	local pname = player:get_player_name()
	local rp = player_rte_prog[pname]
	if rp then
		-- determine what the punched node is
		if minetest.get_item_group(node.name, "at_il_track_circuit_break") >= 1 then
			-- get position of the assigned tcb
			local meta = minetest.get_meta(pos)
			local tcbpts = meta:get_string("tcb_pos")
			if tcbpts == "" then 
				chat(pname, "This TCB is unconfigured, you first need to assign it to a rail")
				return
			end
			local tcbpos = minetest.string_to_pos(tcbpts)
			
			-- track circuit break, try to advance route over it
			local lri = get_last_route_item(rp.origin, rp.route)
			if vector.equals(lri.p, tcbpos) then
				chat(pname, "You cannot continue the route to where you came from!")
				return
			end
			
			local start_tcbs = advtrains.interlocking.db.get_tcbs(lri)
			if not start_tcbs.ts_id then
				chat(pname, "The previous TCB was End of Interlocking. Please complete route programming using '/at_rp_set <name>'")
				return
			end
			
			local ts = advtrains.interlocking.db.get_ts(start_tcbs.ts_id)
			if not ts then atwarn("Internal error, ts inexistant for id!") return end
			local found = nil
			for _,sigd in ipairs(ts.tc_breaks) do
				if vector.equals(sigd.p, tcbpos) then
					found = otherside(sigd.s)
				end
			end
			if not found then
				chat(pname, "Previous and this TCB belong to different track sections!")
				return
			end
			-- TODO check the path: are all route turnouts locked to the right position?
			
			-- everything worked, just add the other side to the list
			table.insert(rp.route, {next = {p = tcbpos, s = found}, locks = rp.tmp_lcks})
			rp.tmp_lcks = {}
			chat(pname, "Added track section '"..ts.name.."' to the route (revert with /at_rp_back)")
			advtrains.interlocking.visualize_route(rp.origin, rp.route, "prog_"..pname, rp.tmp_lcks, pname)
			return
		end
		local ndef = minetest.registered_nodes[node.name]
		if ndef and ndef.luaautomation and ndef.luaautomation.getstate then
			local pts = advtrains.roundfloorpts(pos)
			if rp.tmp_lcks[pts] then
				clear_lock(rp.tmp_lcks, pname, pts)
			else
				local state = ndef.luaautomation.getstate
				if type(state)=="function" then
					state = state(pos, node)
				end
				rp.tmp_lcks[pts] = state
				chat(pname, pts.." is held in "..state.." position when this route is set and freed ")
			end
			advtrains.interlocking.visualize_route(rp.origin, rp.route, "prog_"..pname, rp.tmp_lcks, pname)
			return
		end
		
	end
end)

minetest.register_chatcommand("at_rp_set",
	{
        params = "<name>", -- Short parameter description
        description = "Completes route programming procedure", -- Full description
        privs = {}, -- TODO
        func = function(pname, param)
			return advtrains.pcall(function()
				if param=="" then
					return false, "Missing name parameter!" 
				end
				local rp = player_rte_prog[pname]
				if rp then
					if #rp.route <= 0 then
						return false, "Cannot program route without a target"
					end
					rp.route.name = param
					
					local tcbs = advtrains.interlocking.db.get_tcbs(rp.origin)
					if not tcbs then
						return false, "The origin TCB of this route doesn't exist!"
					end
					
					table.insert(tcbs.routes, rp.route)
					
					advtrains.interlocking.clear_visu_context("prog_"..pname)
					player_rte_prog[pname] = nil
					return true, "Successfully programmed route" 
				end
				return false, "You were not programming a route!" 
			end)
        end,
    })
    
minetest.register_chatcommand("at_rp_back",
	{
        params = "", -- Short parameter description
        description = "Remove last route segment", -- Full description
        privs = {}, -- Require the "privs" privilege to run
        func = function(pname, param)
			return advtrains.pcall(function()
				local rp = player_rte_prog[pname]
				if rp then
					if #rp.route.tcbpath <= 0 then
						return false, "Cannot backtrack when there are no route elements"
					end
					rp.route.tcbpath[#rp.route.tcbpath] = nil
					advtrains.interlocking.visualize_route(rp.origin, rp.route, "prog_"..pname)
					return true, "Route section "..(#rp.route.tcbpath+1).." removed." 
				end
				return false, "You were not programming a route!" 
			end)
        end,
    })
minetest.register_chatcommand("at_rp_mark",
	{
        params = "", -- Short parameter description
        description = "Re-set route programming markers", -- Full description
        privs = {}, -- TODO
        func = function(pname, param)
			return advtrains.pcall(function()
				local rp = player_rte_prog[pname]
				if rp then
					advtrains.interlocking.visualize_route(rp.origin, rp.route, "prog_"..pname)
					return true, "Redrawn route markers" 
				end
				return false, "You were not programming a route!" 
			end)
        end,
    })
minetest.register_chatcommand("at_rp_discard",
	{
        params = "", -- Short parameter description
        description = "Discards the currently programmed route", -- Full description
        privs = {}, -- Require the "privs" privilege to run
        func = function(pname, param)
			return advtrains.pcall(function()
				player_rte_prog[pname] = nil
				advtrains.interlocking.clear_visu_context("prog_"..pname)
				return true, "Route discarded" 
			end)
        end,
    })


--TODO on route setting
-- unify luaautomation get/setstate interface to the core
-- privileges for route programming
-- routes should end at signals. complete route setting by punching a signal, and command as exceptional route completion
