-- serialize_lib
--[[
	Copyright (C) 2020  Moritz Blei (orwell96) and contributors

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.
]]--

serialize_lib = {}

--[[ Configuration table
Whenever asked for a "config", the following table structure is expected:
config = {
	skip_empty_tables = false	-- if true, does not store empty tables
								-- On next read, keys that mapped to empty tables resolve to nil
								-- Used by: write_table_to_file
}
Not all functions use all of the parameters, so you can simplify your config sometimes
]]

-- log utils
-- =========


function serialize_lib.log_error(text)
	minetest.log("error", "[serialize_lib] ("..(minetest.get_current_modname() or "?").."): "..(text or "<nil>"))
end
function serialize_lib.log_warn(text)
	minetest.log("warning", "[serialize_lib] ("..(minetest.get_current_modname() or "?").."): "..(text or "<nil>"))
end
function serialize_lib.log_info(text)
	minetest.log("action", "[serialize_lib] ("..(minetest.get_current_modname() or "?").."): "..(text or "<nil>"))
end
function serialize_lib.log_debug(text)
	minetest.log("action", "[serialize_lib] ("..(minetest.get_current_modname() or "?")..") DEBUG: "..(text or "<nil>"))
end

-- basic serialization/deserialization
-- ===================================

local mp = minetest.get_modpath(minetest.get_current_modname())
serialize_lib.serialize = dofile(mp.."/serialize.lua")
dofile(mp.."/atomic.lua")

local ser = serialize_lib.serialize

-- Opens the passed filename, and returns deserialized table
-- When an error occurs, logs an error and returns false
function serialize_lib.read_table_from_file(filename)
	local succ, ret = pcall(ser.read_from_file, filename)
	if not succ then
		serialize_lib.log_error(ret)
		return false,ret
	end
	return ret
end

-- Writes table into file
-- When an error occurs, logs an error and returns false
function serialize_lib.write_table_to_file(root_table, filename)
	local succ, ret = pcall(ser.write_to_file, root_table, filename)
	if not succ then
		serialize_lib.log_error(ret)
		return false,ret
	end
	return true
end


