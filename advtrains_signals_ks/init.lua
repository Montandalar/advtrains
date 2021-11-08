-- Ks signals
-- Can display main aspects (no Zs) + Sht

-- Note that the group value of advtrains_signal is 2, which means "step 2 of signal capabilities"
-- advtrains_signal=1 is meant for signals that do not implement set_aspect.

local function asp_to_zs3type(asp)
	local n = tonumber(asp)
	if not n or n < 4 then return "off" end
	if n < 8 then return 2*math.floor(n/2) end
	return math.min(16,4*math.floor(n/4))
end

local function setzs3(msp, lim, rot)
	local pos = {x = msp.x, y = msp.y+1, z = msp.z}
	local node = advtrains.ndb.get_node(pos)
	local asp = asp_to_zs3type(lim)
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
	local asp = asp_to_zs3type(lim)
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
		if not asp.dst or asp.dst == -1 then
			advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:hs_free_"..rot, param2 = node.param2})
		elseif asp.dst == 0 then
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
advtrains.trackplacer.register_tracktype("advtrains_signals_ks:sign_lf")
advtrains.trackplacer.register_tracktype("advtrains_signals_ks:sign_lf7")
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
		advtrains.trackplacer.add_worked("advtrains_signals_ks:hs", typ, "_"..rot)
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
		advtrains.trackplacer.add_worked("advtrains_signals_ks:ra", typ, "_"..rot)
	end

	-- Schilder:
	local function register_sign(prefix, typ, nxt, description, mesh, tile2, dtyp, inv, asp)
		minetest.register_node("advtrains_signals_ks:"..prefix.."_"..typ.."_"..rot, {
			description = description,
			drawtype = "mesh",
			mesh = "advtrains_signals_ks_"..mesh.."_smr"..rot..".obj",
			tiles = {"advtrains_signals_ks_signpost.png", tile2},
			
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
				not_in_creative_inventory = (rtab.ici and typ == dtyp) and 0 or 1,
			},
			drop = "advtrains_signals_ks:"..prefix.."_"..dtyp.."_0",
			inventory_image = inv,
			advtrains = {
				get_aspect = function() return asp end
			},
			on_rightclick = advtrains.interlocking.signal_rc_handler,
			can_dig = advtrains.interlocking.signal_can_dig,
			after_dig_node = advtrains.interlocking.signal_after_dig,
		})
		-- rotatable by trackworker
		advtrains.trackplacer.add_worked("advtrains_signals_ks:"..prefix, typ, "_"..rot, nxt)
	end

	for typ, prts in pairs {
		["hfs"] = {asp = {main = false, shunt = false}, n = "pam", mesh = "_hfs"},
		["pam"] = {asp = {main = -1, shunt = false, proceed_as_main = true}, n = "hfs"}
	} do
		local mesh = prts.mesh or ""
		local tile2 = "advtrains_signals_ks_sign_lf7.png^(advtrains_signals_ks_sign_"..typ..".png^[makealpha:255,255,255)"
		if typ == "hfs" then
			tile2 = "advtrains_signals_ks_sign_hfs.png"
		end
		register_sign("sign", typ, prts.n, "Signal Sign", "sign"..mesh, tile2, "hfs", "advtrains_signals_ks_sign_lf7.png", prts.asp)
	end
	
	for typ, prts in pairs {
		-- Speed restrictions:
		["4"] = {asp = { main = 4, shunt = true }, n = "6"},
		["6"] = {asp = { main = 6, shunt = true }, n = "8"},
		["8"] = {asp = { main = 8, shunt = true }, n = "12"},
		["12"] = {asp = { main = 12, shunt = true }, n = "16"},
		["16"] = {asp = { main = 16, shunt = true }, n = "e"},
		-- Speed restriction lifted
		["e"] = {asp = { main = -1, shunt = true }, n = "4", mesh = "_zs10"},
	} do
		local mesh = tonumber(typ) and "_zs3" or prts.mesh or ""
		local tile2 = "[combine:40x40:0,0=\\(advtrains_signals_ks_sign_off.png\\^[resize\\:40x40\\):3,-2=advtrains_signals_ks_sign_"..typ..".png^[invert:rgb"
		if typ == "e" then
			tile2 = "advtrains_signals_ks_sign_zs10.png"
		end
		register_sign("sign", typ, prts.n, "Permanent local speed restriction sign", "sign"..mesh, tile2, "8", "advtrains_signals_ks_sign_8.png^[invert:rgb", prts.asp)
	end

	for typ, prts in pairs {
		["4"]   = {main =  4, n = "6"},
		["6"]   = {main =  6, n = "8"},
		["8"]   = {main =  8, n = "12"},
		["12"]  = {main = 12, n = "16"},
		["16"]  = {main = 16, n = "e"},
		["e"] = {main = -1, n = "4"},
	} do
		local tile2 = "advtrains_signals_ks_sign_lf7.png^(advtrains_signals_ks_sign_"..typ..".png^[makealpha:255,255,255)"..(typ == "e" and "" or "^[multiply:orange")
		local inv = "advtrains_signals_ks_sign_lf7.png^(advtrains_signals_ks_sign_8.png^[makealpha:255,255,255)^[multiply:orange"
		register_sign("sign_lf", typ, prts.n, "Temporary local speed restriction sign", "sign", tile2, "8", inv, {main = prts.main, shunt = true, type = "temp"})
	end

	for typ, prts in pairs {
		["4"]   = {main =  4, n = "6"},
		["6"]   = {main =  6, n = "8"},
		["8"]   = {main =  8, n = "12"},
		["12"]  = {main = 12, n = "16"},
		["16"]  = {main = 16, n = "20"},
		["20"]  = {main = 20, n = "4"},
	} do
		local tile2 = "advtrains_signals_ks_sign_lf7.png^(advtrains_signals_ks_sign_"..typ..".png^[makealpha:255,255,255)"
		local inv = "advtrains_signals_ks_sign_lf7.png^(advtrains_signals_ks_sign_8.png^[makealpha:255,255,255)"
		register_sign("sign_lf7", typ, prts.n, "Line speed restriction sign", "sign", tile2, "8", inv, {main = prts.main, shunt = true, type = "line"})
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
			tiles = {"advtrains_signals_ks_mast.png","advtrains_signals_ks_head.png","advtrains_signals_ks_sign_"..typ..".png^[invert:rgb^[noalpha"},
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
		advtrains.trackplacer.add_worked("advtrains_signals_ks:zs3", typ, "_"..rot)

		-- Zs 3v
		local t = table.copy(def)
		t.description = "Ks distant speed limit indicator"
		t.mesh = "advtrains_signals_ks_zs_bottom_smr"..rot..".obj"
		t.drop = "advtrains_signals_ks:zs3v_off_0"
		t.tiles[3] = t.tiles[3] .. "^[multiply:yellow"
		minetest.register_node("advtrains_signals_ks:zs3v_"..typ.."_"..rot, t)
		advtrains.trackplacer.add_worked("advtrains_signals_ks:zs3v", typ, "_"..rot)
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

minetest.register_craft{
	output = "advtrains_signals_ks:sign_8_0 1",
	recipe = {{"advtrains_signals_ks:sign_lf7_8_0"}}
}

minetest.register_craft{
	output = "advtrains_signals_ks:sign_hfs_0 1",
	recipe = {{"advtrains_signals_ks:sign_8_0"}}
}

minetest.register_craft{
	output = "advtrains_signals_ks:sign_lf_8_0 1",
	recipe = {{"advtrains_signals_ks:sign_hfs_0"}}
}

minetest.register_craft{
	output = "advtrains_signals_ks:sign_lf7_8_0 1",
	recipe = {{"advtrains_signals_ks:sign_lf_8_0"}}
}
