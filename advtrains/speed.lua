-- auxiliary functions for the reworked speed restriction system

local function s_lessp(a, b)
	if not a or a == -1 then
		return false
	elseif not b or b == -1 then
		return true
	else
		return a < b
	end
end

local function s_greaterp(a, b)
	return s_lessp(b, a)
end

local function s_not_lessp(a, b)
	return not s_lessp(a, b)
end

local function s_not_greaterp(a, b)
	return not s_greaterp(a, b)
end

local function s_equalp(a, b)
	return (a or -1) == (b or -1)
end

local function s_not_equalp(a, b)
	return (a or -1) ~= (b or -1)
end

local function s_max(a, b)
	if s_lessp(a, b) then
		return b
	else
		return a
	end
end

local function s_min(a, b)
	if s_lessp(a, b) then
		return a
	else
		return b
	end
end

local function get_speed_restriction_from_table (tbl)
	local strictest = -1
	for _, v in pairs(tbl) do
		strictest = s_min(strictest, v)
	end
	if strictest == -1 then
		return nil
	end
	return strictest
end

local function set_speed_restriction (tbl, rtype, rval)
	if rval then
		tbl[rtype or "main"] = rval
	end
	return tbl
end

local function set_speed_restriction_for_train (train, rtype, rval)
	local t = train.speed_restrictions_t or {main = train.speed_restriction}
	train.speed_restrictions_t = set_speed_restriction(t, rtype, rval)
	train.speed_restriction = get_speed_restriction_from_table(t)
end

local function merge_speed_restriction_from_aspect_to_train (train, asp)
	return set_speed_restriction_for_train(train, asp.type, asp.main)
end

return {
	lessp = s_lessp,
	greaterp = s_greaterp,
	not_lessp = s_not_lessp,
	not_greaterp = s_not_greaterp,
	equalp = s_equalp,
	not_equalp = s_not_equalp,
	max = s_max,
	min = s_min,
	set_restriction = set_speed_restriction_for_train,
	merge_aspect = merge_speed_restriction_from_aspect_to_train,
}
