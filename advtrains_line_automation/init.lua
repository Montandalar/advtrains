-- Advtrains line automation system

advtrains.lines = {}


local modpath = minetest.get_modpath(minetest.get_current_modname()) .. DIR_DELIM

dofile(modpath.."stoprail.lua")


function advtrains.lines.load(data)
	
end

function advtrains.lines.save()
	return {}
end
