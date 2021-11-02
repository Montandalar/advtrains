-- mesecon_controller.lua
-- Mesecon-interfaceable Operation Panel alternative
-- Looks like a Mesecon Luacontroller

-- Luacontroller Adapted Code
-- From Mesecons mod https://mesecons.net/
-- (c) Jeija and Contributors

local BASENAME = "advtrains_luaautomation:mesecon_controller"

local rules = {
	a = {x = -1, y = 0, z =  0, name="A"},
	b = {x =  0, y = 0, z =  1, name="B"},
	c = {x =  1, y = 0, z =  0, name="C"},
	d = {x =  0, y = 0, z = -1, name="D"},
}

local function generate_name(ports)
	local d = ports.d and 1 or 0
	local c = ports.c and 1 or 0
	local b = ports.b and 1 or 0
	local a = ports.a and 1 or 0
	return BASENAME..d..c..b..a
end


local function set_port(pos, rule, state)
	if state then
		mesecon.receptor_on(pos, {rule})
	else
		mesecon.receptor_off(pos, {rule})
	end
end

local function clean_port_states(ports)
	ports.a = ports.a and true or false
	ports.b = ports.b and true or false
	ports.c = ports.c and true or false
	ports.d = ports.d and true or false
end

-- Local table for storing which Mesecons off events should be ignored
-- Indexed by hex encoded position
local ignored_off_events = {}

local function set_port_states(pos, ports)
	local node = advtrains.ndb.get_node(pos)
	local name = node.name
	clean_port_states(ports)
	local vports = minetest.registered_nodes[name].virtual_portstates
	local new_name = generate_name(ports)

	if name ~= new_name and vports then
		-- Problem:
		-- We need to place the new node first so that when turning
		-- off some port, it won't stay on because the rules indicate
		-- there is an onstate output port there.
		-- When turning the output off then, it will however cause feedback
		-- so that the luacontroller will receive an "off" event by turning
		-- its output off.
		-- Solution / Workaround:
		-- Remember which output was turned off and ignore next "off" event.
		local ph=minetest.pos_to_string(pos)
		local railtbl = atlatc.active.nodes[ph]
		if not railtbl then return end

		local ign = railtbl.ignored_off_events or {}
		if ports.a and not vports.a and not mesecon.is_powered(pos, rules.a) then ign.A = true end
		if ports.b and not vports.b and not mesecon.is_powered(pos, rules.b) then ign.B = true end
		if ports.c and not vports.c and not mesecon.is_powered(pos, rules.c) then ign.C = true end
		if ports.d and not vports.d and not mesecon.is_powered(pos, rules.d) then ign.D = true end
		railtbl.ignored_off_events = ign

		advtrains.ndb.swap_node(pos, {name = new_name, param2 = node.param2})

		-- Apply mesecon state only if node loaded
		-- If node is not loaded, mesecon update will occur on next load via on_updated_from_nodedb
		if advtrains.is_node_loaded(pos) then
			if ports.a ~= vports.a then set_port(pos, rules.a, ports.a) end
			if ports.b ~= vports.b then set_port(pos, rules.b, ports.b) end
			if ports.c ~= vports.c then set_port(pos, rules.c, ports.c) end
			if ports.d ~= vports.d then set_port(pos, rules.d, ports.d) end
		end
	end
end

local function on_updated_from_nodedb(pos, newnode, oldnode)
	-- Switch appropriate Mesecon receptors depending on the node change
	local vports = minetest.registered_nodes[oldnode.name].virtual_portstates
	local ports = minetest.registered_nodes[newnode.name].virtual_portstates
	if ports.a ~= vports.a then set_port(pos, rules.a, ports.a) end
	if ports.b ~= vports.b then set_port(pos, rules.b, ports.b) end
	if ports.c ~= vports.c then set_port(pos, rules.c, ports.c) end
	if ports.d ~= vports.d then set_port(pos, rules.d, ports.d) end
end

local function ignore_offevent(pos, rule)
	local ph=minetest.pos_to_string(pos)
	local railtbl = atlatc.active.nodes[ph]
	if not railtbl then return nil end
	local ign = railtbl.ignored_off_events
	if ign and ign[rule.name] then
		ign[rule.name] = nil
		return true
	end
	return false
end

local valid_ports = {a=true, b=true, c=true, d=true}

local function fire_event(pos, evtdata)
	local customfct={
		set_mesecon_outputs = function(states)
			assertt(states, "table")
			set_port_states(pos, states)
		end,
		get_mesecon_input = function(port)
			local portl = string.lower(port)
			if not valid_ports[portl] then
				error("get_mesecon_input: Invalid port (expected a,b,c,d)")
			end
			if mesecon.is_powered(pos, rules[portl]) then
				return true
			end
			return false
		end,
	}
	atlatc.active.run_in_env(pos, evtdata, customfct, true)
	
end

local output_rules = {}
local input_rules = {}

local node_box = {
	type = "fixed",
	fixed = {
		{-8/16, -8/16, -8/16, 8/16, -7/16, 8/16}, -- Bottom slab
		{-5/16, -7/16, -5/16, 5/16, -6/16, 5/16}, -- Circuit board
		{-3/16, -6/16, -3/16, 3/16, -5/16, 3/16}, -- IC
	}
}

local selection_box = {
	type = "fixed",
	fixed = { -8/16, -8/16, -8/16, 8/16, -5/16, 8/16 },
}

for a = 0, 1 do -- 0 = off  1 = on
for b = 0, 1 do
for c = 0, 1 do
for d = 0, 1 do
	local cid = tostring(d)..tostring(c)..tostring(b)..tostring(a)
	local node_name = BASENAME..cid
	local top = "atlatc_luacontroller_top.png"
	if a == 1 then
		top = top.."^atlatc_luacontroller_LED_A.png"
	end
	if b == 1 then
		top = top.."^atlatc_luacontroller_LED_B.png"
	end
	if c == 1 then
		top = top.."^atlatc_luacontroller_LED_C.png"
	end
	if d == 1 then
		top = top.."^atlatc_luacontroller_LED_D.png"
	end

	local groups
	if a + b + c + d ~= 0 then
		groups = {dig_immediate=2, not_in_creative_inventory=1, save_in_at_nodedb=1}
	else
		groups = {dig_immediate=2, save_in_at_nodedb=1}
	end

	output_rules[cid] = {}
	input_rules[cid] = {}
	if a == 1 then table.insert(output_rules[cid], rules.a) end
	if b == 1 then table.insert(output_rules[cid], rules.b) end
	if c == 1 then table.insert(output_rules[cid], rules.c) end
	if d == 1 then table.insert(output_rules[cid], rules.d) end

	if a == 0 then table.insert( input_rules[cid], rules.a) end
	if b == 0 then table.insert( input_rules[cid], rules.b) end
	if c == 0 then table.insert( input_rules[cid], rules.c) end
	if d == 0 then table.insert( input_rules[cid], rules.d) end

	local mesecons = {
		effector = {
			rules = input_rules[cid],
			action_change = function (pos, _, rule_name, new_state)
				if new_state == "off" then
					-- check for ignored off event on this node
					if ignore_offevent(pos, rule_name) then
						return
					end
				end
				--Note: rule_name is not a *name* but actually the full rule table (position + name field)
				--Event format consistent with Mesecons Luacontroller event
				atlatc.interrupt.add(0, pos, {type=new_state, [new_state]=true, pin=rule_name})
			end,
		},
		receptor = {
			state = mesecon.state.on,
			rules = output_rules[cid]
		},
	}

	minetest.register_node(node_name, {
		description = "LuaATC Mesecon Controller",
		drawtype = "nodebox",
		tiles = {
			top,
			"atlatc_luacontroller_bottom.png",
			"atlatc_luacontroller_sides.png",
			"atlatc_luacontroller_sides.png",
			"atlatc_luacontroller_sides.png",
			"atlatc_luacontroller_sides.png"
		},
		inventory_image = top,
		paramtype = "light",
		is_ground_content = false,
		groups = groups,
		drop = BASENAME.."0000",
		sunlight_propagates = true,
		selection_box = selection_box,
		node_box = node_box,
		mesecons = mesecons,
		-- Virtual portstates are the ports that
		-- the node shows as powered up (light up).
		virtual_portstates = {
			a = a == 1,
			b = b == 1,
			c = c == 1,
			d = d == 1,
		},
		after_dig_node = function (pos, node, player)
			mesecon.receptor_off(pos, output_rules)
			atlatc.active.after_dig_node(pos, node, player)
		end,
		after_place_node = atlatc.active.after_place_node,
		on_receive_fields = atlatc.active.on_receive_fields,
		advtrains = {
			on_updated_from_nodedb = on_updated_from_nodedb
		},
		luaautomation = {
			fire_event=fire_event
		},
		digiline = {
			receptor = {},
			effector = {
				action = atlatc.active.on_digiline_receive
			},
		},
	})
end
end
end
end
