-- occupation.lua
--[[
Collects and manages positions where trains occupy and/or reserve/require space

It turned out that, especially for the TSS, some more, even overlapping zones are required.
Packing those into a data structure would just become a huge mess!
Instead, this occupation system will store the path indices of positions in the corresponding.
train's paths.
So, the occupation is a reverse lookup of paths.
Then, a callback system will handle changes in those indices, as follows:

Whenever the train generates new path items (path_get/path_create), their counterpart indices will be filled in here.
Whenever a path gets invalidated or path items are deleted, their index counterpart is erased from here.

When a train needs to know whether a position is blocked by another train, it will (and is permitted to)
query the train.index and train.end_index and compare them to the blocked position's index.

Callback system for 3rd-party path checkers:
advtrains.te_register_on_new_path(func(id, train))
-- Called when a train's path is re-initalized, either when it was invalidated
-- or the saves were just loaded
-- It can be assumed that everything is in the state of when the last run
-- of on_update was made, but all indices are shifted by an unknown amount.

advtrains.te_register_on_update(func(id, train))
-- Called each step and after a train moved, its length changed or some other event occured
-- The path is unmodified, and train.index and train.end_index can be reliably
-- queried for the new position and length of the train.
-- note that this function might be called multiple times per step, and this 
-- function being called does not necessarily mean that something has changed.
-- It is ensured that on_new_path callbacks are executed prior to these callbacks whenever
-- an invalidation or a reload occured.

advtrains.te_register_on_create(func(id, train))
-- Called right after a train is created, right after the initial new_path callback
advtrains.te_register_on_remove(func(id, train))
-- Called right before a train is deleted


All callbacks are allowed to save certain values inside the train table, but they must ensure that
those are reinitialized in the on_new_path callback. The on_new_path callback must explicitly
set ALL OF those values to nil or to a new updated value, and must not rely on their existence.

]]--
local o = {}

local occ = {}
local occ_chg = {}


local function occget(p)
	local t = occ[p.y]
	if not t then
		occ[p.y] = {}
		t = occ[p.y]
	end
	local s = t
	t = t[p.x]
	if not t then
		s[p.x] = {}
		t = s[p.x]
	end
	return t[p.z]
end
local function occgetcreate(p)
	local t = occ[p.y]
	if not t then
		occ[p.y] = {}
		t = occ[p.y]
	end
	local s = t
	t = t[p.x]
	if not t then
		s[p.x] = {}
		t = s[p.x]
	end
	s = t
	t = t[p.z]
	if not t then
		s[p.z] = {}
		t = s[p.z]
	end
	return t
end


function o.set_item(train_id, pos, idx)
	local t = occgetcreate(pos)
	assert(idx)
	local i = 1
	while t[i] do
		if t[i]==train_id and t[i+1]==index then
			break
		end
		i = i + 2
	end
	t[i] = train_id
	t[i+1] = idx
end


function o.clear_all_items(train_id, pos)
	local t = occget(pos)
	if not t then return end
	local i = 1
	while t[i] do
		if t[i]==train_id then
			table.remove(t, i)
			table.remove(t, i)
		else
			i = i + 2
		end
	end
end
function o.clear_specific_item(train_id, pos, index)
	local t = occget(pos)
	if not t then return end
	local i = 1
	while t[i] do
		if t[i]==train_id and t[i+1]==index then
			table.remove(t, i)
			table.remove(t, i)
		else
			i = i + 2
		end
	end
end

-- Checks whether some other train (apart from train_id) has it's 0 zone here
function o.check_collision(pos, train_id)
	local npos = advtrains.round_vector_floor_y(pos)
	local t = occget(npos)
	if not t then return end
	local i = 1
	while t[i] do
		local ti = t[i]
		if ti~=train_id then
			local idx = t[i+1]
			local train = advtrains.trains[ti]
			
			--atdebug("checking train",t[i],"index",idx,"<>",train.index,train.end_index)
			if train and idx >= train.end_index and idx <= train.index then
				--atdebug("collides.")				
				return train -- return train it collided with so we can couple when shunting is enabled
			end
		end
		i = i + 2
	end
	return false
end

-- Gets a mapping of train id's to indexes of trains that have a path item at this position
-- Note that the case where 2 or more indices are at a position only occurs if there is a track loop.
-- returns (table with train_id->{index1, index2...})
function o.reverse_lookup(ppos)
	local pos = advtrains.round_vector_floor_y(ppos)
	local t = occget(pos)
	if not t then return {} end
	local r = {}
	local i = 1
	while t[i] do
		if t[i]~=train_id then
			if not r[t[i]] then r[t[i]] = {} end
			table.insert(r[t[i]], t[i+1])
		end
		i = i + 2
	end
	return r
end

-- Gets a mapping of train id's to indexes of trains that have a path item at this position.
-- Quick variant: will only return one index per train (the latest one added)
-- returns (table with train_id->index)
function o.reverse_lookup_quick(ppos)
	local pos = advtrains.round_vector_floor_y(ppos)
	local t = occget(pos)
	if not t then return {} end
	local r = {}
	local i = 1
	while t[i] do
		r[t[i]] = t[i+1]
		i = i + 2
	end
	return r
end

local OCC_CLOSE_PROXIMITY = 3
-- Gets a mapping of train id's to index of trains that have a path item at this position. Selects at most one index based on a given heuristic, or even none if it does not match the heuristic criterion
-- returns (table with train_id->index), position
-- "in_train": first index that lies between train index and end index
-- "first_ahead": smallest index that is > current index
-- "before_end"(default): smallest index that is > end index
-- "close_proximity": within 3 indices close to the train index and end_index
-- "any": just output the first index found and do not check further (also occurs if both "in_train" and "first_ahead" heuristics have failed
function o.reverse_lookup_sel(pos, heuristic)
	if not heuristic then heuristic = "before_end" end
	local om = o.reverse_lookup(pos)
	local r = {}
	for tid, idxs in pairs(om) do
		r[tid] = idxs[1]
		if heuristic~="any" then
			--must run a heuristic
			--atdebug("reverse_lookup_sel is running heuristic for", pos,heuristic,"idxs",table.concat(idxs,","))
			local otrn = advtrains.trains[tid]
			advtrains.train_ensure_init(tid, otrn)
			local h_value
			for _,idx in ipairs(idxs) do
				if heuristic == "first_ahead" and idx > otrn.index and (not h_value or h_value>idx) then
					h_value = idx
				end
				if heuristic == "before_end" and idx > otrn.end_index and (not h_value or h_value>idx) then
					h_value = idx
				end
				if heuristic == "in_train" and idx < otrn.index and idx > otrn.end_index then
					h_value = idx
				end
				if heuristic == "close_proximity" and idx < (otrn.index + OCC_CLOSE_PROXIMITY) and idx > (otrn.end_index - OCC_CLOSE_PROXIMITY) then
					h_value = idx
				end
			end
			r[tid] = h_value
			--atdebug(h_value,"chosen")
		end
	end
	return r, pos
end
-- Gets a mapping of train id's to indexes of trains that stand or drive over
-- returns (table with train_id->index)
function o.get_trains_at(ppos)
	local pos = advtrains.round_vector_floor_y(ppos)
	return o.reverse_lookup_sel(pos, "in_train")
end

advtrains.occ = o
