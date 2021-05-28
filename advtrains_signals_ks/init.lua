-- Ks signals
-- Can display main aspects (no Zs) + Sht

-- Note that the group value of advtrains_signal is 2, which means "step 2 of signal capabilities"
-- advtrains_signal=1 is meant for signals that do not implement set_aspect.

local supported_speed_limits = {
	[4] = true, [6] = true, [8] = true, [12] = true, [16] = true
}

local function setzs3(msp, lim, rot)
	local pos = {x = msp.x, y = msp.y+1, z = msp.z}
	local node = advtrains.ndb.get_node(pos)
	local asp = lim
	if not asp or not supported_speed_limits[lim] then asp = "off" end
	if node.name:find("^advtrains_signals_ks:zs3_") then
		advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:zs3_"..asp.."_"..rot, param2 = node.param2})
	end
end

local function getzs3(msp)
	local pos = {x = msp.x, y = msp.y+1, z = msp.z}
	local nodename = advtrains.ndb.get_node(pos).name
	local speed = nodename:match("^advtrains_signals_ks:zs3_(%w+)_%d+$")
	if not speed then return nil end
	speed = tonumber(speed)
	if not speed then return false end
	return speed
end

local function setzs3v(msp, lim, rot)
	local pos = {x = msp.x, y = msp.y-1, z = msp.z}
	local node = advtrains.ndb.get_node(pos)
	local asp = lim
	if not asp or not supported_speed_limits[lim] then asp = "off" end
	if node.name:find("^advtrains_signals_ks:zs3v_") then
		advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:zs3v_"..asp.."_"..rot, param2 = node.param2})
	end
end

local function getzs3v(msp)
	local pos = {x = msp.x, y = msp.y-1, z = msp.z}
	local nodename = advtrains.ndb.get_node(pos).name
	local speed = nodename:match("^advtrains_signals_ks:zs3v_(%w+)_%d+$")
	if not speed then return nil end
	speed = tonumber(speed)
	if not speed then return false end
	return speed
end

local setaspectf = function(rot)
 return function(pos, node, asp)
	setzs3(pos, asp.main, rot)
	if asp.main == 0 then
		if asp.shunt then
			advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:hs_shunt_"..rot, param2 = node.param2})
		else
			advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:hs_danger_"..rot, param2 = node.param2})
		end
		setzs3v(pos, nil, rot)
	else
		if asp.dst == -1 then
			advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:hs_free_"..rot, param2 = node.param2})
		elseif not asp.dst or asp.dst == 0 then
			advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:hs_slow_"..rot, param2 = node.param2})
		else
			advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:hs_nextslow_"..rot, param2 = node.param2})
		end
		setzs3v(pos, asp.dst, rot)
	end
 end
end


local suppasp = {
		main = {0, 4, 6, 8, 12, 16, -1},
		dst = {0, 4, 6, 8, 12, 16, -1, false},
		shunt = nil,
		proceed_as_main = true,
		info = {
			call_on = false,
			dead_end = false,
			w_speed = nil,
		}
}

--Rangiersignal
local setaspectf_ra = function(rot)
 return function(pos, node, asp)
	if asp.shunt then
		advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:ra_shuntd_"..rot, param2 = node.param2})
	else
		advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:ra_danger_"..rot, param2 = node.param2})
	end
	local meta = minetest.get_meta(pos)
	if meta then
		meta:set_string("infotext", minetest.serialize(asp))
	end
 end
end

local suppasp_ra = {
		main = { false },
		dst = { false },
		shunt = nil,
		proceed_as_main = false,
		
		info = {
			call_on = false,
			dead_end = false,
			w_speed = nil,
		}
}

advtrains.trackplacer.register_tracktype("advtrains_signals_ks:hs")
advtrains.trackplacer.register_tracktype("advtrains_signals_ks:ra")
advtrains.trackplacer.register_tracktype("advtrains_signals_ks:sign")
advtrains.trackplacer.register_tracktype("advtrains_signals_ks:zs3")
advtrains.trackplacer.register_tracktype("advtrains_signals_ks:zs3v")
advtrains.trackplacer.register_tracktype("advtrains_signals_ks:mast")

for _, rtab in ipairs({
		{rot =  "0", sbox = {-1/8, -1/2, -1/2,  1/8, 1/2, -1/4}, ici=true},
		{rot = "30", sbox = {-3/8, -1/2, -1/2, -1/8, 1/2, -1/4},},
		{rot = "45", sbox = {-1/2, -1/2, -1/2, -1/4, 1/2, -1/4},},
		{rot = "60", sbox = {-1/2, -1/2, -3/8, -1/4, 1/2, -1/8},},
	}) do
	local rot = rtab.rot
	for typ, prts in pairs({
			danger   = {asp = advtrains.interlocking.DANGER, n = "slow", ici=true},
			slow     = {
				asp = function(pos)
					return { main = getzs3(pos) or -1, proceed_as_main = true, dst = 0 }
				end,
				n = "nextslow"
			},
			nextslow = {
				asp = function(pos)
					return { main = getzs3(pos) or -1, proceed_as_main = true, dst = getzs3v(pos) or 6 }
				end,
				n = "free"
			},
			free     = {
				asp = function(pos)
					return { main = getzs3(pos) or -1, proceed_as_main = true, dst = -1 }
				end,
	                        n = "shunt"
			},
			shunt    = {asp = { main =  0, shunt = true} , n = "danger"},
		}) do
		local tile = "advtrains_signals_ks_ltm_"..typ..".png"
		local afunc = prts.asp
		if type(afunc) == "table" then
			afunc = function() return prts.asp end
		end
		if typ == "nextslow" then
			tile = {
				name = tile,
				animation = {
					type = "vertical_frames",
					aspect_w = 32,
					aspect_h = 32,
					length = 1,
				}
			}
		end
		minetest.register_node("advtrains_signals_ks:hs_"..typ.."_"..rot, {
			description = "Ks Main Signal",
			drawtype = "mesh",
			mesh = "advtrains_signals_ks_main_smr"..rot..".obj",
			tiles = {"advtrains_signals_ks_mast.png", "advtrains_signals_ks_head.png", "advtrains_signals_ks_head.png", tile},
			
			paramtype="light",
			sunlight_propagates=true,
			light_source = 4,
			
			paramtype2 = "facedir",
			selection_box = {
				type = "fixed",
				fixed = {rtab.sbox, {-1/4, -1/2, -1/4, 1/4, -7/16, 1/4}}
			},
			groups = {
				cracky = 2,
				advtrains_signal = 2,
				not_blocking_trains = 1,
				save_in_at_nodedb = 1,
				not_in_creative_inventory = (rtab.ici and prts.ici) and 0 or 1,
			},
			drop = "advtrains_signals_ks:hs_danger_0",
			inventory_image = "advtrains_signals_ks_hs_inv.png",
			advtrains = {
				set_aspect = setaspectf(rot),
				supported_aspects = suppasp,
				get_aspect = afunc,
			},
			on_rightclick = advtrains.interlocking.signal_rc_handler,
			can_dig = advtrains.interlocking.signal_can_dig,
			after_dig_node = advtrains.interlocking.signal_after_dig,
		})
		-- rotatable by trackworker
		advtrains.trackplacer.add_worked("advtrains_signals_ks:hs", typ, "_"..rot, prts.n)
	end
	
	
	--Rangiersignale:
	for typ, prts in pairs({
			danger = {asp = { main = false, shunt = false }, n = "shuntd", ici=true},
			shuntd = {asp = { main = false, shunt = true } , n = "danger"},
		}) do
		minetest.register_node("advtrains_signals_ks:ra_"..typ.."_"..rot, {
			description = "Ks Shunting Signal",
			drawtype = "mesh",
			mesh = "advtrains_signals_ks_sht_smr"..rot..".obj",
			tiles = {"advtrains_signals_ks_mast.png", "advtrains_signals_ks_head.png", "advtrains_signals_ks_head.png", "advtrains_signals_ks_ltm_"..typ..".png"},
			
			paramtype="light",
			sunlight_propagates=true,
			light_source = 4,
			
			paramtype2 = "facedir",
			selection_box = {
				type = "fixed",
				fixed = {-1/4, -1/2, -1/4, 1/4, 0, 1/4}
			},
			groups = {
				cracky = 2,
				advtrains_signal = 2,
				not_blocking_trains = 1,
				save_in_at_nodedb = 1,
				not_in_creative_inventory = (rtab.ici and prts.ici) and 0 or 1,
			},
			drop = "advtrains_signals_ks:ra_danger_0",
			inventory_image = "advtrains_signals_ks_ra_inv.png",
			advtrains = {
				set_aspect = setaspectf_ra(rot),
				supported_aspects = suppasp_ra,
				get_aspect = function(pos, node)
					return prts.asp
				end,
			},
			on_rightclick = advtrains.interlocking.signal_rc_handler,
			can_dig = advtrains.interlocking.signal_can_dig,
			after_dig_node = advtrains.interlocking.signal_after_dig,
		})
		-- rotatable by trackworker
		advtrains.trackplacer.add_worked("advtrains_signals_ks:ra", typ, "_"..rot, prts.n)
	end
	
	--Schilder:
	for typ, prts in pairs({
			-- Speed restrictions:
			["8"] = {asp = { main = 8, shunt = true }, n = "12", ici=true},
			["12"] = {asp = { main = 12, shunt = true }, n = "16"},
			["16"] = {asp = { main = 16, shunt = true }, n = "e"},
			-- Speed restriction lifted
			["e"] = {asp = { main = -1, shunt = true }, n = "hfs"},
			-- Halt for shunt moves:
			["hfs"] = {asp = { main = false, shunt = false }, n = "pam"},
			["pam"] = {asp = { main = -1, shunt = false, proceed_as_main = true}, n = "8"},
		}) do
		minetest.register_node("advtrains_signals_ks:sign_"..typ.."_"..rot, {
			description = "Signal Sign",
			drawtype = "mesh",
			mesh = "advtrains_signals_ks_sign"..(typ == "hfs" and "_hfs" or "").."_smr"..rot..".obj",
			tiles = {"advtrains_signals_ks_signpost.png", "advtrains_signals_ks_sign_"..typ..".png"},
			
			paramtype="light",
			sunlight_propagates=true,
			light_source = 4,
			
			paramtype2 = "facedir",
			selection_box = {
				type = "fixed",
				fixed = {rtab.sbox, {-1/4, -1/2, -1/4, 1/4, -7/16, 1/4}}
			},
			groups = {
				cracky = 2,
				advtrains_signal = 2,
				not_blocking_trains = 1,
				save_in_at_nodedb = 1,
				not_in_creative_inventory = (rtab.ici and prts.ici) and 0 or 1,
			},
			drop = "advtrains_signals_ks:sign_8_0",
			inventory_image = "advtrains_signals_ks_sign_8.png",
			advtrains = {
				-- This is a static signal! No set_aspect
				get_aspect = function(pos, node)
					return prts.asp
				end,
			},
			on_rightclick = advtrains.interlocking.signal_rc_handler,
			can_dig = advtrains.interlocking.signal_can_dig,
			after_dig_node = advtrains.interlocking.signal_after_dig,
		})
		-- rotatable by trackworker
		advtrains.trackplacer.add_worked("advtrains_signals_ks:sign", typ, "_"..rot, prts.n)
	end
	
	-- Geschwindigkeits(vor)anzeiger für Ks-Signale
	for typ, prts in pairs({
			["off"] = {n = "4", ici = true},
			["4"] = {n = "6"},
			["6"] = {n = "8"},
			["8"] = {n = "12"},
			["12"] = {n = "16"},
			["16"] = {n = "off"},
		}) do
		local def = {
			drawtype = "mesh",
			tiles = {"advtrains_signals_ks_mast.png","advtrains_signals_ks_head.png","[combine:128x128:0,4=advtrains_signals_ks_zs3_"..typ..".png^[noalpha"},
			paramtype = "light",
			sunlight_propagates = true,
			light_source = 4,
			paramtype2 = "facedir",
			selection_box = {
				type = "fixed",
				fixed = {rtab.sbox, {-1/4, -1/2, -1/4, 1/4, -7/16, 1/4}}
			},
			groups = {
				cracky = 2,
				not_blocking_trains = 1,
				save_in_at_nodedb = 1,
				not_in_creative_inventory = (rtab.ici and prts.ici) and 0 or 1,
			},
			after_dig_node = function(pos) advtrains.ndb.update(pos) end
		}

		-- Zs 3
		local t = table.copy(def)
		t.description = "Ks speed limit indicator"
		t.mesh = "advtrains_signals_ks_zs_top_smr"..rot..".obj"
		t.drop = "advtrains_signals_ks:zs3_off_0"
		t.selection_box.fixed[1][5] = 0
		minetest.register_node("advtrains_signals_ks:zs3_"..typ.."_"..rot, t)
		advtrains.trackplacer.add_worked("advtrains_signals_ks:zs3", typ, "_"..rot, prts.n)

		-- Zs 3v
		local t = table.copy(def)
		t.description = "Ks distant speed limit indicator"
		t.mesh = "advtrains_signals_ks_zs_bottom_smr"..rot..".obj"
		t.drop = "advtrains_signals_ks:zs3v_off_0"
		t.tiles[3] = t.tiles[3] .. "^[multiply:yellow"
		minetest.register_node("advtrains_signals_ks:zs3v_"..typ.."_"..rot, t)
		advtrains.trackplacer.add_worked("advtrains_signals_ks:zs3v", typ, "_"..rot, prts.n)
	end
	
	minetest.register_node("advtrains_signals_ks:mast_mast_"..rot, {
		description = "Ks Mast",
		drawtype = "mesh",
		mesh = "advtrains_signals_ks_mast_smr"..rot..".obj",
		tiles = {"advtrains_signals_ks_mast.png"},
		
		paramtype="light",
		sunlight_propagates=true,
		--light_source = 4,
		
		paramtype2 = "facedir",
		selection_box = {
			type = "fixed",
			fixed = {rtab.sbox, {-1/4, -1/2, -1/4, 1/4, -7/16, 1/4}}
		},
		groups = {
			cracky = 2,
			not_blocking_trains = 1,
			not_in_creative_inventory = (rtab.ici) and 0 or 1,
		},
		drop = "advtrains_signals_ks:mast_mast_0",
	})
	advtrains.trackplacer.add_worked("advtrains_signals_ks:mast","mast", "_"..rot)
end

-- Crafting

minetest.register_craft({
	output = "advtrains_signals_ks:hs_danger_0 2",
	recipe = {
		{'default:steel_ingot', 'dye:red', 'default:steel_ingot'},
		{'dye:yellow', 'default:steel_ingot', 'dye:dark_green'},
		{'default:steel_ingot', 'advtrains_signals_ks:mast_mast_0', 'default:steel_ingot'},
	},
})

minetest.register_craft({
	output = "advtrains_signals_ks:mast_mast_0 10",
	recipe = {
		{'default:steel_ingot'},
		{'dye:cyan'},
		{'default:steel_ingot'},
	},
})

minetest.register_craft({
	output = "advtrains_signals_ks:ra_danger_0 2",
	recipe = {
		{'dye:red', 'dye:white', 'dye:red'},
		{'dye:white', 'default:steel_ingot', 'default:steel_ingot'},
		{'default:steel_ingot', 'advtrains_signals_ks:mast_mast_0', 'default:steel_ingot'},
	},
})

local sign_material = "default:sign_wall_steel" --fallback
if minetest.get_modpath("basic_materials") then
	sign_material = "basic_materials:plastic_sheet"
end
--print("Sign Material: "..sign_material)

minetest.register_craft({
	output = "advtrains_signals_ks:sign_8_0 2",
	recipe = {
		{sign_material, 'dye:black'},
		{'default:stick', ''},
		{'default:stick', ''},
	},
})
sign_material = nil
