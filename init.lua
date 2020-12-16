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
	minetest.log("error", "[serialize_lib] "..text)
end
function serialize_lib.log_warn(text)
	minetest.log("warning", "[serialize_lib] "..text)
end
function serialize_lib.log_info(text)
	minetest.log("action", "[serialize_lib] "..text)
end
function serialize_lib.log_debug(text)
	minetest.log("action", "[serialize_lib](debug) "..text)
end

-- basic serialization/deserialization
-- ===================================

local ser = dofile("serialize.lua")

-- Opens the passed filename, and returns deserialized table
-- When an error occurs, logs an error and returns false
function serialize_lib.read_table_from_file(filename)
	local succ, err = pcall(ser.read_from_file, filename)
	if not succ then
		serialize_lib.log_error("Mod '"..minetest.get_current_modname().."': "..err)
	end
	return succ
end

-- Writes table into file
-- When an error occurs, logs an error and returns false
function serialize_lib.write_table_to_file(filename)
	local succ, err = pcall(ser.write_to_file, filename)
	if not succ then
		serialize_lib.log_error("Mod '"..minetest.get_current_modname().."': "..err)
	end
	return succ
end

-- Managing files and backups
-- ==========================

--[[
The plain scheme just overwrites the file in place. This however poses problems when we are interrupted right within
the write, so we have incomplete data. So, the following scheme is applied:
1. writes to <filename>.new (if .new already exists, try to complete the moving first)
2. moves <filename> to <filename>.old, possibly overwriting an existing file (special windows behavior)
3. moves <filename>.new to <filename>

During loading, we apply the following order of precedence:
1. <filename>.new
2. <filename>
3. <filename>.old

Normal case: <filename> and <filename>.old exist, loading <filename>
Interrupted during write: .new is damaged, loads last regular state
Interrupted during the move operations: either <filename>.new or <filename> represents the latest state
Other corruption: at least the .old state may still be present

]]--


