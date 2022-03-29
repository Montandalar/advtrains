-- depends on default, digilines and mesecons for crafting recipes
if minetest.settings:get_bool("advtrains_luaautomation_enable_atlac_recipes",false) == true then
	minetest.register_craft({
		output = "advtrains_luaautomation:dtrack_placer",
		recipe = {
			{"","digilines:wire_std_00000000",""},
			{"","advtrains:dtrack_atc_placer",""},
			{"","mesecons_luacontroller:luacontroller0000",""}
		}
	})
	
	minetest.register_craft({
		output = "advtrains_luaautomation:mesecon_controller0000",
		recipe = {
			{"","group:mesecon_conductor_craftable",""},
			{"group:mesecon_conductor_craftable","advtrains_luaautomation:dtrack_placer","group:mesecon_conductor_craftable"},
			{"","group:mesecon_conductor_craftable",""}
		}
	})

	minetest.register_craft({
		output = "advtrains_luaautomation:oppanel",
		recipe = {
			{"","mesecons_button:button_off",""},
			{"","advtrains_luaautomation:mesecon_controller0000",""},
			{"","default:stone",""}
		}
	})
end