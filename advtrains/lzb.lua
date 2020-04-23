-- lzb.lua
-- Enforced and/or automatic train override control, providing the on_train_approach callback

--[[
Documentation of train.lzb table
train.lzb = {
	trav_index = Current index that the traverser has advanced so far
	checkpoints = table containing oncoming signals, in order of index
		{
			pos = position of the point
			index = where this is on the path
			speed = speed allowed to pass. nil = no effect
			callback = function(pos, id, train, index, speed, lzbdata)
			-- Function that determines what to do on the train in the moment it drives over that point.
			-- When spd==0, called instead when train has stopped in front
			-- nil = no effect
			lzbdata = {}
			-- Table of custom data filled in by approach callbacks
			-- Whenever an approach callback inserts an LZB checkpoint with changed lzbdata,
			-- all consecutive approach callbacks will see these passed as lzbdata table.
		}
	trav_lzbdata = currently active lzbdata table at traverser index
}
each step, for every item in "oncoming", we need to determine the location to start braking (+ some safety margin)
and, if we passed this point for at least one of the items, initiate brake.
When speed has dropped below, say 3, decrease the margin to zero, so that trains actually stop at the signal IP.
The spd variable and travsht need to be updated on every aspect change. it's probably best to reset everything when any aspect changes
]]


local params = {
	BRAKE_SPACE = 10,
	AWARE_ZONE  = 50,

	ADD_STAND  =  2.5,
	ADD_SLOW   =  1.5,
	ADD_FAST   =  7,
	ZONE_ROLL  =  2,
	ZONE_HOLD  =  5, -- added on top of ZONE_ROLL
	ZONE_VSLOW =  3, -- When speed is <2, still allow accelerating

	DST_FACTOR =  1.5,

	SHUNT_SPEED_MAX = advtrains.SHUNT_SPEED_MAX,
}

function advtrains.set_lzb_param(par, val)
	if params[par] and tonumber(val) then
		params[par] = tonumber(val)
	else
		error("Inexistant param or not a number")
	end
end

local function resolve_latest_lzbdata(ckp, index)
	local i = #ckp
	local ckpi
	while i>0 do
		ckpi = ckp[i]
		if ckpi.index <= index and ckpi.lzbdata then
			return ckpi.lzbdata
		end
	end
end

local function look_ahead(id, train)
	
	local acc = advtrains.get_acceleration(train, 1)
	local vel = train.velocity
	local brakedst = ( -(vel*vel) / (2*acc) ) * params.DST_FACTOR
	
	local brake_i = advtrains.path_get_index_by_offset(train, train.index, brakedst + params.BRAKE_SPACE)
	--local aware_i = advtrains.path_get_index_by_offset(train, brake_i, AWARE_ZONE)
	
	local lzb = train.lzb
	local trav = lzb.trav_index
	-- retrieve latest lzbdata
	local lzbdata = lzb.trav_lzbdata

	if lzbdata.off_track then
		--previous position was off track, do not scan any further
	end
	
	while trav <= brake_i do
		local pos = advtrains.path_get(train, trav)
		-- check offtrack
		if trav - 1 == train.path_trk_f then
			lzbdata.off_track = true
			advtrains.lzb_add_checkpoint(train, trav - 1, 0, nil, lzbdata)
		else
			-- run callbacks
			-- Note: those callbacks are defined in trainlogic.lua for consistency with the other node callbacks
			advtrains.tnc_call_approach_callback(pos, id, train, trav, lzb.trav_lzbdata)
			
		end
		trav = trav + 1
		
	end
	
	lzb.trav_index = trav
	
end

-- Flood-fills train.path_speed, based on this checkpoint 
local function apply_checkpoint_to_path(train, checkpoint)
	if not checkpoint.speed then
		return
	end
	-- make sure path exists until checkpoint
	local pos = advtrains.path_get(train, checkpoint.index)
	
	local brake_accel = advtrains.get_acceleration(train, 11)
	
	-- start with the checkpoint index at specified speed
	local index = checkpoint.index
	local p_speed -- speed in path_speed
	local c_speed = checkpoint.speed -- calculated speed at current index
	while true do
		p_speed = train.path_speed[index]
		if (p_speed and p_speed <= c_speed) or index < train.index then
			--we're done. train already slower than wanted at this position
			return
		end
		-- insert calculated target speed
		train.path_speed[index] = c_speed
		-- calculate c_speed at previous index
		advtrains.path_get(train, index-1)
		local eldist = train.path_dist[index] - train.path_dist[index-1]
		-- Calculate the start velocity the train would have if it had a end velocity of c_speed and accelerating with brake_accel, after a distance of eldist:
		-- v0² = v1² - 2*a*s
		c_speed = math.sqrt( (c_speed * c_speed) - (2 * brake_accel * eldist) )
		index = index - 1
	end
	
end

--[[
Distance needed to accelerate from v0 to v1 with constant acceleration a:

         v1 - v0     a   / v1 - v0 \ 2     v1^2 - v0^2
s = v0 * -------  +  - * | ------- |    =  -----------
            a        2   \    a    /           2*a
]]

-- Removes all LZB checkpoints and restarts the traverser at the current train index
function advtrains.lzb_invalidate(train)
	train.lzb = {
		trav_index = atround(train.index),
		trav_lzbdata = {},
		checkpoints = {},
	}
end

-- LZB part of path_invalidate_ahead. Clears all checkpoints that are ahead of start_idx
-- in contrast to path_inv_ahead, doesn't complain if start_idx is behind train.index, clears everything then
function advtrains.lzb_invalidate_ahead(train, start_idx)
	if train.lzb then
		local idx = atfloor(start_idx)
		local i = 1
		while train.lzb.checkpoints[i] do
			if train.lzb.checkpoints[i].idx >= idx then
				table.remove(train.lzb.checkpoints, i)
			else
				i=i+1
			end
		end
		-- re-apply all checkpoints to path_speed
		train.path_speed = {}
		for _,ckp in train.lzb.checkpoints do
			apply_checkpoint_to_path(train, ckp)
		end
	end
end

-- Add LZB control point
-- lzbdata: If you modify lzbdata in an approach callback, you MUST add a checkpoint AND pass the (modified) lzbdata into it.
-- If you DON'T modify lzbdata, you MUST pass nil as lzbdata. Always modify the lzbdata table in place, never overwrite it!
function advtrains.lzb_add_checkpoint(train, index, speed, callback, lzbdata)
	local lzb = train.lzb
	local pos = advtrains.path_get(train, index)
	local lzbdata_c = nil
	if lzbdata then
		-- make a shallow copy of lzbdata
		lzbdata_c = {}
		for k,v in pairs(lzbdata) do lzbdata_c[k] = v end
	end
	local ckp = {
		pos = pos,
		index = index,
		speed = speed,
		callback = callback,
		lzbdata = lzbdata_c,
	}
	table.insert(lzb.checkpoints, ckp)
	
	apply_checkpoint_to_path(train, ckp)
end


advtrains.te_register_on_new_path(function(id, train)
	advtrains.lzb_invalidate(train)
	look_ahead(id, train)
end)

advtrains.te_register_on_invalidate_ahead(function(id, train)
	advtrains.lzb_invalidate_ahead(train, start_idx)
end)

advtrains.te_register_on_update(function(id, train)
	if not train.path or not train.lzb then
		atprint("LZB run: no path on train, skip step")
		return
	end
	look_ahead(id, train)
	--apply_control(id, train)
end, true)
