-- p_mesecon_iface.lua
-- Mesecons interface by overriding the switch

if minetest.get_modpath("mesecons_switch") == nil then return end

minetest.override_item("mesecons_switch:mesecon_switch_off", {
	groups = {
		dig_immediate=2,
		save_in_at_nodedb=1,
	},
	on_rightclick = function (pos, node)
		advtrains.ndb.swap_node(pos, {name="mesecons_switch:mesecon_switch_on", param2=node.param2})
		mesecon.receptor_on(pos)
		minetest.sound_play("mesecons_switch", {pos=pos})
	end,
	advtrains = {
		getstate = "off",
		setstate = function(pos, node, newstate)
			if newstate=="on" then
				advtrains.ndb.swap_node(pos, {name="mesecons_switch:mesecon_switch_on", param2=node.param2})
				if advtrains.is_node_loaded(pos) then
					mesecon.receptor_on(pos)
				end
			end
		end,
		on_updated_from_nodedb = function(pos, node)
			mesecon.receptor_off(pos)
		end,
	},
})

minetest.override_item("mesecons_switch:mesecon_switch_on", {
	groups = {
		dig_immediate=2,
		save_in_at_nodedb=1,
		not_in_creative_inventory=1,
	},
	on_rightclick = function (pos, node)
		advtrains.ndb.swap_node(pos, {name="mesecons_switch:mesecon_switch_off", param2=node.param2})
		mesecon.receptor_off(pos)
		minetest.sound_play("mesecons_switch", {pos=pos})
	end,
	advtrains = {
		getstate = "on",
		setstate = function(pos, node, newstate)
			if newstate=="off" then
				advtrains.ndb.swap_node(pos, {name="mesecons_switch:mesecon_switch_off", param2=node.param2})
				if advtrains.is_node_loaded(pos) then
					mesecon.receptor_off(pos)
				end
			end
		end,
		fallback_state = "off",
		on_updated_from_nodedb = function(pos, node)
			mesecon.receptor_on(pos)
		end,
	},
})
