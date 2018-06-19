-- Signal API implementation


--[[ Signal aspect table:
asp = {
	main = {
		free = <boolean>,
		speed = <int km/h>,
	},
	shunt = {
		free = <boolean>,
	}
	dst = {
		free = <boolean>,
		speed = <int km/h>,
	}
	info = {
		call_on = <boolean>, -- Call-on route, expect train in track ahead
		dead_end = <boolean>, -- Route ends on a dead end (e.g. bumper)
	}
}
Signals API:
groups = {
	advtrains_signal = 1,
	save_in_at_nodedb = 1,
}
advtrains = {
	function set_aspect(pos, node, asp)
		...
	end
}
on_rightclick = advtrains.interlocking.signal_rc_handler

]]--

function advtrains.interlocking.signal_set_aspect(pos, asp)
	local node=advtrains.ndb.get_node(pos)
	local ndef=minetest.registered_nodes[node.name]
	if ndef and ndef.advtrains and ndef.advtrains.set_aspect then
		ndef.advtrains.set_aspect(pos, node, asp)
	end
end

function advtrains.interlocking.signal_rc_handler(pos, node, player, itemstack, pointed_thing)
	local pname = player:get_player_name()
	minetest.show_formspec(pname, "at_il_sigasp_"..minetest.pos_to_string(pos), "field[aspect;Set Aspect (F/D)Speed(F/D)Speed(F/D);D0D0D]")
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local pts = string.match(formname, "^at_il_sigasp_(.+)$")
	local pos
	if pts then pos = minetest.string_to_pos(pts) end
	if pos and fields.aspect then
		local mfs, msps, dfs, dsps, shs = string.match(fields.aspect, "^([FD])([0-9]+)([FD])([0-9]+)([FD])$")
		local asp = {
			main = {
				free = mfs=="F",
				speed = tonumber(msps),
			},
			shunt = {
				free = shs=="F",
			},
			dst = {
				free = dfs=="F",
				speed = tonumber(dsps),
			},
			info = {
				call_on = false, -- Call-on route, expect train in track ahead
				dead_end = false, -- Route ends on a dead end (e.g. bumper)
			}
		}
		advtrains.interlocking.signal_set_aspect(pos, asp)
	end
end)
