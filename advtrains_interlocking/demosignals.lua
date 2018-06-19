-- Demonstration signals
-- Those can display the 3 main aspects of Ks signals


minetest.register_node("advtrains_interlocking:ds_danger", {
	description = "Demo signal at Danger",
	tiles = {"at_il_signal_asp_danger.png"},
	groups = {
		cracky = 3,
		advtrains_signal = 1,
		save_in_at_nodedb = 1,
	},
	sounds = default.node_sound_stone_defaults(),
	advtrains = {
		set_aspect = function(pos, node, asp)
			if asp.main.free then
				if asp.dst.free and asp.main.speed > 50 then
					advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_free"})
				else
					advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_slow"})
				end
			else
				advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_danger"})
			end
			local meta = minetest.get_meta(pos)
			if meta then
				meta:set_string("infotext", minetest.serialize(asp))
			end
		end
	},
	on_rightclick = advtrains.interlocking.signal_rc_handler
})
minetest.register_node("advtrains_interlocking:ds_free", {
	description = "Demo signal at Free",
	tiles = {"at_il_signal_asp_free.png"},
	groups = {
		cracky = 3,
		advtrains_signal = 1,
		save_in_at_nodedb = 1,
	},
	sounds = default.node_sound_stone_defaults(),
	advtrains = {
		set_aspect = function(pos, node, asp)
			if asp.main.free then
				if asp.dst.free and asp.main.speed > 50 then
					advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_free"})
				else
					advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_slow"})
				end
			else
				advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_danger"})
			end
			local meta = minetest.get_meta(pos)
			if meta then
				meta:set_string("infotext", minetest.serialize(asp))
			end
		end
	},
	on_rightclick = advtrains.interlocking.signal_rc_handler
})
minetest.register_node("advtrains_interlocking:ds_slow", {
	description = "Demo signal at Slow",
	tiles = {"at_il_signal_asp_slow.png"},
	groups = {
		cracky = 3,
		advtrains_signal = 1,
		save_in_at_nodedb = 1,
	},
	sounds = default.node_sound_stone_defaults(),
	advtrains = {
		set_aspect = function(pos, node, asp)
			if asp.main.free then
				if asp.dst.free and asp.main.speed > 50 then
					advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_free"})
				else
					advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_slow"})
				end
			else
				advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_danger"})
			end
			local meta = minetest.get_meta(pos)
			if meta then
				meta:set_string("infotext", minetest.serialize(asp))
			end
		end
	},
	on_rightclick = advtrains.interlocking.signal_rc_handler
})

