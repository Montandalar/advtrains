-- test the serialization function


package.path  =  "../?.lua;" .. package.path




_G.advtrains = {}
_G.advtrains.interlocking = {}

require("ars")

local arstb = {{ ln="Foo"}, {c="Bar"}, {n=true, rc="Boo"}}
local arsdef = {{ ln="Foo"}, {c="Bar"}, {rc="Boo"}, default=true}
local arstr = [[LN Foo
#Bar
!RC Boo]]
local defstr = [[*
LN Foo
#Bar
RC Boo]]
il = _G.advtrains.interlocking

describe("ars_to_text", function ()
				it("read table", function ()
						assert.equals(il.ars_to_text(arstb),arstr)
				end)
				it("reads back and forth", function ()
						assert.equals(il.ars_to_text(il.text_to_ars(arstr)),arstr)
				end)
				it("handles default routes properly", function ()
						assert.equals(il.ars_to_text(arsdef),defstr)
				end)
end)

describe("text_to_ars", function ()
				it("writes table", function()
						assert.same(il.text_to_ars(arstr),arstb)
				end)
				it("handles default routes properly", function ()
						assert.same(il.text_to_ars(defstr),arsdef)
				end)				
end)

train1 = {}
train2 = {}
train3 = {}
train1.line = "Foo"
train1.routingcode = "Boo"
train2.line= "Bar"
train2.routingcode = "NotBoo NotBoo"
train3.routingcode = "Foo Boo Moo Zoo"

describe("check_rule_match", function  ()
				it("matches rules correctly", function()
						assert.equals(il.ars_check_rule_match(arstb,train1),1)
						assert.equals(il.ars_check_rule_match(arsdef,train2),nil)
				end)
				it("matches negative rules", function()
						assert.equals(il.ars_check_rule_match(arstb,train2),3)
						assert.equals(il.ars_check_rule_match(arstb,train3),nil)
				end)
				it("matches RC in a list correctly", function()
						assert.equals(il.ars_check_rule_match(arsdef,train3),3)
				end)
end)
