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
