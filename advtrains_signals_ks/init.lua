-- Ks signals
-- Can display main aspects (no Zs) + Sht

-- Note that the group value of advtrains_signal is 2, which means "step 2 of signal capabilities"
-- advtrains_signal=1 is meant for signals that do not implement set_aspect.

local setaspectf = function(rot)
 return function(pos, node, asp)
	if not asp.main.free then
		if asp.shunt.free then
			advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:hs_shunt_"..rot, param2 = node.param2})
		else
			advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:hs_danger_"..rot, param2 = node.param2})
		end
	else
		if asp.dst.free and asp.main.speed == -1 then
			advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:hs_free_"..rot, param2 = node.param2})
		else
			advtrains.ndb.swap_node(pos, {name="advtrains_signals_ks:hs_slow_"..rot, param2 = node.param2})
		end
	end
	local meta = minetest.get_meta(pos)
	if meta then
		meta:set_string("infotext", minetest.serialize(asp))
	end
 end
end

local suppasp = {
		main = {
			free = nil,
			speed = {6, -1},
		},
		dst = {
			free = nil,
			speed = nil,
		},
		shunt = {
			free = nil,
			proceed_as_main = true,
		},
		info = {
			call_on = false,
			dead_end = false,
			w_speed = nil,
		}
}

advtrains.trackplacer.register_tracktype("advtrains_signals_ks:hs")
advtrains.trackplacer.register_tracktype("advtrains_signals_ks:mast")

for _, rtab in ipairs({
		{rot =  "0", sbox = {-1/8, -1/2, -1/2,  1/8, 1, -1/4}, ici=true},
		{rot = "30", sbox = {-3/8, -1/2, -1/2, -1/8, 1, -1/4},},
		{rot = "45", sbox = {-1/2, -1/2, -1/2, -1/4, 1, -1/4},},
		{rot = "60", sbox = {-1/2, -1/2, -3/8, -1/4, 1, -1/8},},
	}) do
	local rot = rtab.rot
	for typ, prts in pairs({
			danger = {asp = advtrains.interlocking.DANGER, n = "slow", ici=true},
			slow   = {asp = { main = { free = true, speed = 6 }} , n = "free"},
			free   = {asp = { main = { free = true, speed = -1 }} , n = "shunt"},
			shunt  = {asp = { main = {free = false}, shunt = {free = true} } , n = "danger"},
		}) do
		minetest.register_node("advtrains_signals_ks:hs_"..typ.."_"..rot, {
			description = "Ks Main Signal",
			drawtype = "mesh",
			mesh = "advtrains_signals_ks_main_smr"..rot..".obj",
			tiles = {"advtrains_signals_ks_mast.png", "advtrains_signals_ks_head.png", "advtrains_signals_ks_head.png", "advtrains_signals_ks_ltm_"..typ..".png"},
			paramtype2 = "facedir",
			selection_box = {
				type = "fixed",
				fixed = {rtab.sbox, {-1/4, -1/2, -1/4, 1/4, -7/16, 1/4}}
			},
			groups = {
				cracky = 2,
				advtrains_signal = 2,
				save_in_at_nodedb = 1,
				not_in_creative_inventory = (rtab.ici and prts.ici) and 0 or 1,
			},
			drop = "advtrains_signals_ks:hs_danger_0",
			inventory_image = "advtrains_signals_ks_hs_inv.png",
			sounds = default.node_sound_stone_defaults(),
			advtrains = {
				set_aspect = setaspectf(rot),
				supported_aspects = suppasp,
				get_aspect = function(pos, node)
					return prts.asp
				end,
			},
			on_rightclick = advtrains.interlocking.signal_rc_handler,
			can_dig = advtrains.interlocking.signal_can_dig,
		})
		-- rotatable by trackworker
		advtrains.trackplacer.add_worked("advtrains_signals_ks:hs", typ, "_"..rot, prts.n)
	end
	
	-- set new sbox clip height
	rtab.sbox[5] = 1/2
	
	minetest.register_node("advtrains_signals_ks:mast_mast_"..rot, {
		description = "Ks Mast",
		drawtype = "mesh",
		mesh = "advtrains_signals_ks_mast_smr"..rot..".obj",
		tiles = {"advtrains_signals_ks_mast.png"},
		paramtype2 = "facedir",
		selection_box = {
			type = "fixed",
			fixed = {rtab.sbox, {-1/4, -1/2, -1/4, 1/4, -7/16, 1/4}}
		},
		groups = {
			cracky = 2,
			not_in_creative_inventory = (rtab.ici) and 0 or 1,
		},
		drop = "advtrains_signals_ks:mast_mast_0",
		sounds = default.node_sound_stone_defaults(),
	})
	advtrains.trackplacer.add_worked("advtrains_signals_ks:mast","mast", "_"..rot)
end

