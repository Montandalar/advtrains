package.path = "./?.lua;../?.lua;" .. package.path
advtrains = {}
_G.advtrains = advtrains

require("mineunit")
mineunit("core")

local recipes = require("recipes")

describe("recipe_matches", function()
	it("Should match the recipe for LuaATC tracks", function()
		local craftgrid = {}
		craftgrid.insert(ItemStack(""))
		craftgrid.insert(ItemStack("digilines:wire_std_00000000"))
	end)
end)

describe("craft_fn", function()
	it("Should restrict access for unprivileged players", function()
	end)
	
	it("Should allow crafting for privileged players", function()
	end)
end)
