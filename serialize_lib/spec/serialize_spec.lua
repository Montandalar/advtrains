-- test the serialization function


package.path  =  "../?.lua;" .. package.path


ser = require("serialize")


local mock_file = {}
_G.mock_file = mock_file
function mock_file:read(arg)
	if arg == "*l" or arg== "*line" then
		local l = self.lines[self.pointer or 1]
		self.pointer = (self.pointer or 1) + 1
		return l
	end
end

function mock_file:close()
	return nil
end

function mock_file:write(text)
	self.content = self.content..text
end

function mock_file:create(lines)
	local f = {}
	setmetatable(f, mock_file)
	f.lines = lines or {}
	f.write = self.write
	f.close = self.close
	f.read = self.read
	f.content = ""
	return f
end


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
local testser = [[LUA_SER v=2
B1:T
Sa:Sb
Sc:B0
E
Skey:Svalue
Ses&&&&ca&&&npe3:Sbaz&&&&bam&&&nbim
N1:Seins
Ses&&&:cape4:Sfoo&n&:bar
Ses&&ca&npe2:Sbaz&&bam&nbim
Ses&:cape1:Sfoo&:bar
E
END_SER
]]

local function check_write(tb, conf)
	f = mock_file:create()
	ser.write_to_fd(tb, f, conf or {})
	return f.content
end

function string:split()
	local fields = {}
   self:gsub("[^\n]+", function(c) fields[#fields+1] = c end)
   return fields
end

local function check_read(text)
	f = mock_file:create(text:split())
	return ser.read_from_fd(f)
end
	
local noskip = [[LUA_SER v=2
N1:T
E
E
END_SER
]]
local skip = [[LUA_SER v=2
E
END_SER
]]

describe("write_to_fd", function()
				it("does not skip empty tables", function()
						assert.equals(check_write({{}}),noskip)
				end)
				it("skips empty tables when needed", function()

						assert.equals(check_write({{}},{skip_empty_tables=true}),skip)
				end)
end)

describe("read_from_fd", function ()
				it("reads a table correctly", function()
						assert.same(check_read(testser),testtable)
				end)
				it("handles some edge cases correctly", function()
						assert.same(check_read(noskip), {{}})
						assert.same(check_read(skip), {})
				end)
				it("Read back table", function()
						local tb = {}
						for k=1,262 do
							tb[k] =  { "Foo", "bar", k}
						end
						assert.same(check_read(check_write(tb)), tb)
				end)
end)
