-- Demonstration signals
-- Those can display the 3 main aspects of Ks signals

-- Note that the group value of advtrains_signal is 2, which means "step 2 of signal capabilities"
-- advtrains_signal=1 is meant for signals that do not implement set_aspect.


local setaspect = function(pos, node, asp)
	if asp.main == 0 then
		advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_danger"})
	else
		if asp.dst ~= 0 and asp.main == -1 then
			advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_free"})
		else
			advtrains.ndb.swap_node(pos, {name="advtrains_interlocking:ds_slow"})
		end
	end
	local meta = minetest.get_meta(pos)
	if meta then
		meta:set_string("infotext", minetest.serialize(asp))
	end
end

local suppasp = {
		main = {0, 6, -1},
		dst = {0, false},
		shunt = false,
		proceed_as_main = true,
		info = {
			call_on = false,
			dead_end = false,
			w_speed = nil,
		}
}

minetest.register_node("advtrains_interlocking:ds_danger", {
	description = "Demo signal at Danger",
	tiles = {"at_il_signal_asp_danger.png"},
	groups = {
		cracky = 3,
		advtrains_signal = 2,
		save_in_at_nodedb = 1,
	},
	advtrains = {
		set_aspect = setaspect,
		supported_aspects = suppasp,
		get_aspect = function(pos, node)
			return advtrains.interlocking.DANGER
		end,
	},
	on_rightclick = advtrains.interlocking.signal_rc_handler,
	can_dig = advtrains.interlocking.signal_can_dig,
	after_dig_node = advtrains.interlocking.signal_after_dig,
})
minetest.register_node("advtrains_interlocking:ds_free", {
	description = "Demo signal at Free",
	tiles = {"at_il_signal_asp_free.png"},
	groups = {
		cracky = 3,
		advtrains_signal = 2,
		save_in_at_nodedb = 1,
	},
	advtrains = {
		set_aspect = setaspect,
		supported_aspects = suppasp,
		get_aspect = function(pos, node)
			return {
				main = -1,
			}
		end,
	},
	on_rightclick = advtrains.interlocking.signal_rc_handler,
	can_dig = advtrains.interlocking.signal_can_dig,
	after_dig_node = advtrains.interlocking.signal_after_dig,
})
minetest.register_node("advtrains_interlocking:ds_slow", {
	description = "Demo signal at Slow",
	tiles = {"at_il_signal_asp_slow.png"},
	groups = {
		cracky = 3,
		advtrains_signal = 2,
		save_in_at_nodedb = 1,
	},
	advtrains = {
		set_aspect = setaspect,
		supported_aspects = suppasp,
		get_aspect = function(pos, node)
			return {
				main = 6,
			}
		end,
	},
	on_rightclick = advtrains.interlocking.signal_rc_handler,
	can_dig = advtrains.interlocking.signal_can_dig,
	after_dig_node = advtrains.interlocking.signal_after_dig,
})

