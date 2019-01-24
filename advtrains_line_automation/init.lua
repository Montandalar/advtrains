-- Advtrains line automation system

advtrains.lines = {
	-- [station code] = {name=..., owner=...}
	stations = {},
	
	--[[ [new pos hash] = {
		stn = <station code>,
		track = <platform identifier>,
		doors = <door side L,R,C>
		wait = <least wait time>
		reverse = <boolean>
		signal = <position of signal that is the "exit signal" for this platform>
	}]]
	stops = {},
}


local modpath = minetest.get_modpath(minetest.get_current_modname()) .. DIR_DELIM

dofile(modpath.."stoprail.lua")


function advtrains.lines.load(data)
	if data then
		advtrains.lines.stations = data.stations or {}
		advtrains.lines.stops = data.stops or {}
	end
end

function advtrains.lines.save()
	return {
		stations = advtrains.lines.stations,
		stops = advtrains.lines.stops
	}
end
