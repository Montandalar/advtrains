-- depends on default, digilines and mesecons for crafting recipes
if minetest.settings:get_bool("advtrains_luaautomation_enable_atlac_recipes",false) == false then
	return
end

-- ACTUAL RECIPES
-- Credit to Maverick2797 for the original recipes.
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

-- PRIV PROTECTION
local priv_recipes = {}

for idx, item_name in pairs({
		"advtrains_luaautomation:dtrack_placer",
		"advtrains_luaautomation:mesecon_controller0000",
		"advtrains_luaautomation:oppanel"
}) do
	local recipe = minetest.get_craft_recipe(item_name).items

	priv_recipes[item_name] = recipe
end

-- Pre-cache groups
local precache_groups = {"mesecon_conductor_craftable"}
local precache_nodes = {}
for item,idef in pairs(minetest.registered_nodes) do
	for _, groupname in pairs(precache_groups) do
		local itemname = idef.name
		if idef.groups[groupname] then
			precache_nodes["group:" .. groupname.. ":" .. itemname] = true
		end
	end
end


-- Helper for the craft predict function.
-- Is duplicating engine functionality REALLY the best solution? Well,
-- hardcoding it would be worse so..
-- Extract this out to advtrains core or a library if this should be reused to
-- priv protect other craft recipes e.g. track_builder, train recipes
local function recipe_matches(craft_grid, priv_recipes)
	local candidate_recipes = {}
	local i = 0
	for k,_ in pairs(priv_recipes) do
		candidate_recipes[i] = priv_recipes[k]
		i = i + 1
	end

	for grid_idx, griditem in pairs(craft_grid) do
		for recipe_idx, recipe in pairs(candidate_recipes) do
			local recipe_item = recipe[grid_idx] or ""
			local griditem_name = griditem:get_name()
			local match = false
			if recipe_item:find("group:") == 1
				and precache_nodes[recipe_item .. ":" .. griditem_name]
			then
				match = true
			end
				
			if recipe_item == griditem_name then
				match = true
			end

			if not match then
				-- pairs is based on next() and next() allows removal during
				-- traversal.
				candidate_recipes[recipe_idx] = nil
			end
		end
	end

	-- More than one candidate is fine for us as long as SOME recipe matches.
	-- Let the actual crafting system sort that problem (if it exists) out.
	return next(candidate_recipes) ~= nil
end

local craft_fn = function(itemstack, player, old_craft_grid, craft_inv)
	if recipe_matches(old_craft_grid, priv_recipes) then
		if not minetest.check_player_privs(player, "atlatc") then
			-- Players will not ordinarily see this message due to the craft
			-- predict. It will also not refund the items. I figure anyone
			-- trying to cheat the item in deserves to lose the materials (but I
			-- also just don't know how to stop that from happening
			-- either :)
			minetest.chat_send_player(
				player:get_player_name(),
				attrans("You need the `atlatc` privilege to craft LuaATC components")
			)
			return ItemStack("")
		else
			return nil
		end
	end
	return nil
end

-- Forbid crafting atlatc items except to players with atlatc priv.
minetest.register_craft_predict(craft_fn)
minetest.register_on_craft(craft_fn)
