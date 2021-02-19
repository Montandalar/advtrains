--advtrains by orwell96, see readme.txt and license.txt
--crafting.lua
--registers crafting recipes

--tracks: see advtrains_train_track
--signals
minetest.register_craft({
	output = 'advtrains:retrosignal_off 2',
	recipe = {
		{'dye:red', 'default:steel_ingot', 'default:steel_ingot'},
		{'', '', 'default:steel_ingot'},
		{'', '', 'default:steel_ingot'},
	},
})
minetest.register_craft({
	output = 'advtrains:signal_off 2',
	recipe = {
		{'', 'dye:red', 'default:steel_ingot'},
		{'', 'dye:dark_green', 'default:steel_ingot'},
		{'', '', 'default:steel_ingot'},
	},
})
--Wallmounted Signal
minetest.register_craft({
	output = 'advtrains:signal_wall_r_off 2',
	recipe = {
		{'dye:red', 'default:steel_ingot', 'default:steel_ingot'},
		{'', 'default:steel_ingot', ''},
		{'dye:dark_green', 'default:steel_ingot', 'default:steel_ingot'},
	},
})

--Wallmounted Signals can be converted into every orientation by shapeless crafting
minetest.register_craft({
	output = 'advtrains:signal_wall_l_off',
	type = "shapeless",
	recipe = {'advtrains:signal_wall_r_off'},
})
minetest.register_craft({
	output = 'advtrains:signal_wall_t_off',
	type = "shapeless",
	recipe = {'advtrains:signal_wall_l_off'},
})
minetest.register_craft({
	output = 'advtrains:signal_wall_r_off',
	type = "shapeless",
	recipe = {'advtrains:signal_wall_t_off'},
})

--trackworker
minetest.register_craft({
	output = 'advtrains:trackworker',
	recipe = {
		{'default:diamond'},
		{'screwdriver:screwdriver'},
		{'default:steel_ingot'},
	},
})

--boiler
minetest.register_craft({
	output = 'advtrains:boiler',
	recipe = {
		{'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
		{'doors:trapdoor_steel', '', 'default:steel_ingot'},
		{'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
	},
})

--drivers'cab
minetest.register_craft({
	output = 'advtrains:driver_cab',
	recipe = {
		{'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
		{'', '', 'default:glass'},
		{'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
	},
})

--drivers'cab
minetest.register_craft({
	output = 'advtrains:wheel',
	recipe = {
		{'', 'default:steel_ingot', ''},
		{'default:steel_ingot', 'group:stick', 'default:steel_ingot'},
		{'', 'default:steel_ingot', ''},
	},
})

--chimney
minetest.register_craft({
	output = 'advtrains:chimney',
	recipe = {
		{'', 'default:steel_ingot', ''},
		{'', 'default:steel_ingot', 'default:torch'},
		{'', 'default:steel_ingot', ''},
	},
})


--misc_nodes
--crafts for platforms see misc_nodes.lua
