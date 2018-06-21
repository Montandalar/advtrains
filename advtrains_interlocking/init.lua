-- Advtrains interlocking system
-- See database.lua for a detailed explanation

advtrains.interlocking = {}

local modpath = minetest.get_modpath(minetest.get_current_modname()) .. DIR_DELIM

dofile(modpath.."database.lua")
dofile(modpath.."tcb_ts_ui.lua")
dofile(modpath.."signal_api.lua")
dofile(modpath.."demosignals.lua")
