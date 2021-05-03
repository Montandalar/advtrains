-- serialize.lua
-- Lua-conformant library file that has no minetest dependencies
-- Contains the serialization and deserialization routines

--[[
Version history:
1 - initial
2 - also escaping CR character as &r

Structure of entry:
[keytype][key]:[valuetype][val]
Types:
	B - bool
		-> 0=false, 1=true
    S - string
		-> see below
    N - number
		-> thing compatible with tonumber()
Table:
[keytype][key]:T
... content is nested in table until the matching
E

example:
LUA_SER v=2		{
Skey:Svalue			key = "value",
N1:Seins			[1] = "eins",
B1:T				[true] = {
Sa:Sb					a = "b",
Sc:B0					c = false,
E					}
E				}

String representations:
In strings the following characters are escaped by &
'&' -> '&&'
(line break) -> '&n'
(CR) -> '&r'
':' -> '&:'
All other characters are unchanged as they bear no special meaning.
]]

local write_table, literal_to_string, escape_chars, table_is_empty

function table_is_empty(t)
	for _,_ in pairs(t) do
		return false
	end
	return true
end

function write_table(t, file, config)
	local ks, vs, writeit, istable
	for key, value in pairs(t) do
		ks = value_to_string(key, false)
		writeit = true
		istable = type(value)=="table"
		
		if istable then
			vs = "T"
			if config and config.skip_empty_tables then
				writeit = not table_is_empty(value)
			end
		else
			vs = value_to_string(value, true)
		end
		
		if writeit then
			file:write(ks..":"..vs.."\n")
			
			if istable then
				write_table(value, file, config)
				file:write("E\n")
			end
		end
	end
end

function value_to_string(t)
	if type(t)=="table" then
		file:close()
		error("Can not serialize a table in the key position!")
	elseif type(t)=="boolean" then
		if t then
			return "B1"
		else
			return "B0"
		end
	elseif type(t)=="number" then
		return "N"..t
	elseif type(t)=="string" then
		return "S"..escape_chars(t)
	else
		--error("Can not serialize '"..type(t).."' type!")
		return "S<function>"
	end
	return str
end

function escape_chars(str)
	local rstr = string.gsub(str, "&", "&&")
	rstr = string.gsub(rstr, ":", "&:")
	rstr = string.gsub(rstr, "\r", "&r")
	rstr = string.gsub(rstr, "\n", "&n")
	return rstr
end

------

local read_table, string_to_value, unescape_chars

function read_table(t, file)
	local line, ks, vs, kv, vv, vt
	while true do
		line = file:read("*l")
		if not line then
			file:close()
			error("Unexpected EOF or read error!")
		end
		-- possibly windows fix: strip trailing \r's from line
		line = string.gsub(line, "\r$", "")
		
		if line=="E" then
			-- done with this table
			return
		end
		ks, vs = string.match(line, "^(.*[^&]):(.+)$")
		if not ks or not vs then
			file:close()
			error("Unable to parse line: '"..line.."'!")
		end
		kv = string_to_value(ks)
		vv, vt = string_to_value(vs, true)
		if vt then
			read_table(vv, file)
		end
		-- put read value in table
		t[kv] = vv
	end
end

-- returns: value, is_table
function string_to_value(str, table_allow)
	local first = string.sub(str, 1,1)
	local rest = string.sub(str, 2)
	if first=="T" then
		if table_allow then
			return {}, true
		else
			file:close()
			error("Table not allowed in key component!")
		end
	elseif first=="N" then
		local num = tonumber(rest)
		if num then
			return num
		else
			file:close()
			error("Unable to parse number: '"..rest.."'!")
		end
	elseif first=="B" then
		if rest=="0" then
			return false
		elseif rest=="1" then
			return true
		else
			file:close()
			error("Unable to parse boolean: '"..rest.."'!")
		end
	elseif first=="S" then
		return unescape_chars(rest)
	else
		file:close()
		error("Unknown literal type '"..first.."' for literal '"..str.."'!")
	end
end

function unescape_chars(str) --TODO
	local rstr = string.gsub(str, "&:", ":")
	rstr = string.gsub(rstr, "&n", "\n")
	rstr = string.gsub(rstr, "&r", "\r")
	rstr = string.gsub(rstr, "&&", "&")
	return rstr
end

------

--[[
config = {
	skip_empty_tables = false	-- if true, does not store empty tables
								-- On next read, keys that mapped to empty tables resolve to nil
}
]]

-- Writes the passed table into the passed file descriptor, and closes the file
local function write_to_fd(root_table, file, config)
	file:write("LUA_SER v=2\n")
	write_table(root_table, file, config)
	file:write("E\nEND_SER\n")
	file:close()
end

-- Reads the file contents from the passed file descriptor and returns the table on success
-- Throws errors when something is wrong. Closes the file.
-- config: see above
local function read_from_fd(file)
	local first_line = file:read("*line")
	-- possibly windows fix: strip trailing \r's from line
	first_line = string.gsub(first_line, "\r$", "")
	if not string.match(first_line, "LUA_SER v=[12]") then
		file:close()
		error("Expected header, got '"..first_line.."' instead!")
	end
	local t = {}
	read_table(t, file)
	local last_line = file:read("*line")
	-- possibly windows fix: strip trailing \r's from line
	last_line = string.gsub(last_line, "\r$", "")
	file:close()
	if last_line ~= "END_SER" then
		error("Missing END_SER, got '"..last_line.."' instead!")
	end
	return t
end

-- Opens the passed filename and serializes root_table into it
-- config: see above
function write_to_file(root_table, filename, config)
	-- try opening the file
	local file, err = io.open(filename, "wb")
	if not file then
		error("Failed opening file '"..filename.."' for write:\n"..err)
	end
	
	write_to_fd(root_table, file, config)
	return true
end

-- Opens the passed filename, and returns its deserialized contents
function read_from_file(filename)
	-- try opening the file
	local file, err = io.open(filename, "rb")
	if not file then
		error("Failed opening file '"..filename.."' for read:\n"..err)
	end
	
	return read_from_fd(file)
end

--[[ simple unit test
local testtable = {
	key = "value",
	[1] = "eins",
	[true] = {
		a = "b",
		c = false,
	},
	["es:cape1"] = "foo:bar",
	["es&ca\npe2"] = "baz&bam\nbim",
	["es&&ca&\npe3"] = "baz&&bam&\nbim",
	["es&:cape4"] = "foo\n:bar"
}
local config = {}
--write_to_file(testtable, "test_out", config)
local t = read_from_file("test_out")
write_to_file(t, "test_out_2", config)
local t2 = read_from_file("test_out_2")
write_to_file(t2, "test_out_3", config)

-- test_out_2 and test_out_3 should be equal

--]]


return {
	read_from_fd = read_from_fd,
	write_to_fd = write_to_fd,
	read_from_file = read_from_file,
	write_to_file = write_to_file,
}
