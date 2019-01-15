-- ars.lua
-- automatic routesetting

--[[
	The "ARS table" and its effects:
	Every route has (or can have) an associated ARS table. This can either be
	ars = { [n] = {ln="<line>"}/{rc="<routingcode>"}/{c="<a comment>"} }
	a list of rules involving either line or routingcode matchers (or comments, those are ignored)
	The first matching rule determines the route to set.
	- or -
	ars = {default = true}
	this means that all trains that no other rule matches on should use this route
	
	Compound ("and") conjunctions are not supported (--TODO should they?)
	
	For editing, those tables are transformed into lines in a text area:
	{ln=...} -> LN ...
	{rc=...} -> RC ...
	{c=...}  -> #...
	{default=true} -> *
	See also route_ui.lua
]]

local il = advtrains.interlocking


local function find_rtematch(routes, train)
	local default
	local line = train.line
	local routingcode
	for rteid, route in ipairs(routes) do
		if route.ars then
			if route.ars.default then
				default = rteid
			else
				for arskey, arsent in ipairs(route.ars) do
					if arsent.ln and line and arsent.ln == line then
						return rteid
					elseif arsent.rc and routingcode and string.match(" "..routingcode.." ", " "..arsent.rc.." ", nil, true) then
						return rteid
					end
				end
			end
		end
	end
	return default
end

function advtrains.interlocking.ars_check(sigd, train)
	local tcbs = il.db.get_tcbs(sigd)
	if not tcbs or not tcbs.routes then return end
	
	if tcbs.routeset then
		-- ARS is not in effect when a route is already set
		return
	end
	
	local rteid = find_rtematch(tcbs.routes, train)
	if rteid then
		il.route.update_route(sigd, tcbs, rteid, nil)
	end
end
