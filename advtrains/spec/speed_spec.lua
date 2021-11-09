package.path = "../?.lua;" .. package.path
advtrains = {}
_G.advtrains = advtrains
local speed = require("speed")

describe("Arithmetic functions on speed restrictions", function()
	it("should work", function()
		local a = math.random()
		local b = math.random(20)
		-- This test is basically a "typo check"
		assert.is_true (speed.lessp(a, b))
		assert.is_false(speed.greaterp(a, b))
		assert.is_false(speed.not_lessp(a, b))
		assert.is_true (speed.not_greaterp(a, b))
		assert.is_false(speed.lessp(a, a))
		assert.is_false(speed.greaterp(a, a))
		assert.is_true (speed.equalp(a, a))
		assert.is_false(speed.not_equalp(a, a))
		assert.equal(b, speed.max(a, b))
		assert.equal(a, speed.min(a, b))
	end)
	it("should handle -1", function()
		assert.is_false(speed.lessp(-1, math.random()))
	end)
	it("should handle nil", function()
		assert.is_true(speed.greaterp(nil, math.random()))
	end)
	it("should handle mixed nil and -1", function()
		assert.is_true(speed.equalp(nil, -1))
	end)
end)

describe("The speed restriction setter", function()
	it("should set the signal aspect", function()
		local t = {speed_restrictions_t = {x = 5, y = 9}}
		local u = {speed_restrictions_t = {x = 7, y = 9}, speed_restriction = 7}
		speed.merge_aspect(t, {main = 7, type = "x"})
		assert.same(u, t)
	end)
	it("should work with existing signal aspect tables", function()
		local t = {speed_restrictions_t = {main = 5, foo = 3}}
		local u = {speed_restrictions_t = {main = 7, foo = 3}, speed_restriction = 3}
		speed.merge_aspect(t, {main = 7})
		assert.same(u, t)
	end)
	it("should work with distant signals", function()
		local t = {speed_restrictions_t = {main = 5}}
		local u = {speed_restrictions_t = {main = 5}, speed_restriction = 5}
		speed.merge_aspect(t, {})
		assert.same(u, t)
	end)
	it("should create the restriction table if necessary", function()
		local t = {speed_restriction = 5}
		local u = {speed_restriction = 3, speed_restrictions_t = {main = 5, foo = 3}}
		speed.merge_aspect(t, {main = 3, type = "foo"})
		assert.same(u, t)
	end)
	it("should also create the restriction table for trains without any speed limit", function()
		local t = {}
		local u = {speed_restrictions_t = {}}
		speed.merge_aspect(t, {})
		assert.same(u, t)
	end)
	it("should set the speed restriction to nil if that is the case", function()
		local t = {speed_restriction = math.random(20)}
		local u = {speed_restrictions_t = {main = -1}}
		speed.merge_aspect(t, {main = -1})
		assert.same(u, t)
	end)
end)
