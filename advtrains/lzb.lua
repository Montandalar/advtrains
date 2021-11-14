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
			
			udata = arbitrary user data, no official way to retrieve (do not use)
		}
	trav_lzbdata = currently active lzbdata table at traverser index
}
The LZB subsystem keeps track of "checkpoints" the train will pass in the future, and has two main tasks:
1. run approach callbacks, and run callbacks when passing LZB checkpoints
2. keep track of the permitted speed at checkpoints, and make sure that the train brakes accordingly
To perform 2, it populates the train.path_speed table which is handled along with the path subsystem.
This table is used in trainlogic.lua/train_step_b() and applied to the velocity calculations.

Note: in contrast to node enter callbacks, which are called when the train passes the .5 index mark, LZB callbacks are executed on passing the .0 index mark!
If an LZB checkpoint has speed 0, the train will still enter the node (the enter callback will be called), but will stop at the 0.9 index mark (for details, see SLOW_APPROACH in trainlogic.lua)

The start point for the LZB traverser (and thus the first node that will receive an approach callback) is floor(train.index) + 1. This means, once the LZB checkpoint callback has fired,
this path node will not receive any further approach callbacks for the same approach situation
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
		i=i-1
	end
	return {}
end

local function look_ahead(id, train)
	local lzb = train.lzb
	if lzb.zero_checkpoint then
		-- if the checkpoints list contains a zero checkpoint, don't look ahead
		-- in order to not trigger approach callbacks on the wrong path
		return
	end
	
	local acc = advtrains.get_acceleration(train, 1)
	-- worst-case: the starting point is maximum speed
	local vel = train.max_speed or train.velocity
	local brakedst = ( -(vel*vel) / (2*acc) ) * params.DST_FACTOR
	
	--local brake_i = advtrains.path_get_index_by_offset(train, train.index, brakedst + params.BRAKE_SPACE)
	-- worst case (don't use index_by_offset)
	local brake_i = atfloor(train.index + brakedst + params.BRAKE_SPACE)
	--atprint("LZB: looking ahead up to ", brake_i)
	
	--local aware_i = advtrains.path_get_index_by_offset(train, brake_i, AWARE_ZONE)
	
	local trav = lzb.trav_index
	-- retrieve latest lzbdata
	if not lzb.trav_lzbdata then
		lzb.trav_lzbdata = resolve_latest_lzbdata(lzb.checkpoints, trav)
	end
	
	if lzb.trav_lzbdata.off_track then
		--previous position was off track, do not scan any further
	end
	
	while trav <= brake_i and not lzb.zero_checkpoint do
		local pos = advtrains.path_get(train, trav)
		-- check offtrack
		if trav - 1 == train.path_trk_f then
			lzb.trav_lzbdata.off_track = true
			advtrains.lzb_add_checkpoint(train, trav - 1, 0, nil, lzb.trav_lzbdata)
		else
			-- run callbacks
			-- Note: those callbacks are defined in trainlogic.lua for consistency with the other node callbacks
			advtrains.tnc_call_approach_callback(pos, id, train, trav, lzb.trav_lzbdata)
			
		end
		trav = trav + 1
		
	end
	
	lzb.trav_index = trav
	
end
advtrains.lzb_look_ahead = look_ahead


local function call_runover_callbacks(id, train)
	if not train.lzb then return end
	
	local i = 1
	local idx = atfloor(train.index)
	local ckp = train.lzb.checkpoints
	while ckp[i] do
		if ckp[i].index <= idx then
			--atprint("LZB: checkpoint run over: i=",ckp[i].index,"s=",ckp[i].speed,"p=",ckp[i].pos)
			-- call callback
			local it = ckp[i]
			if it.callback then
				it.callback(it.pos, id, train, it.index, it.speed, train.lzb.lzbdata)
			end
			-- note: lzbdata is always defined as look_ahead was called before
			table.remove(ckp, i)
		else
			i = i + 1
		end
	end
end

-- Flood-fills train.path_speed, based on this checkpoint 
local function apply_checkpoint_to_path(train, checkpoint)
	if not checkpoint.speed then
		return
	end
	--atprint("LZB: applying checkpoint: i=",checkpoint.index,"s=",checkpoint.speed,"p=",checkpoint.pos)
	
	if checkpoint.speed == 0 then
		train.lzb.zero_checkpoint = true
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
	--advtrains.atprint_context_tid = train.id
	--atprint("LZB: invalidate")
	--advtrains.atprint_context_tid = nil
	train.lzb = {
		trav_index = atfloor(train.index) + 1,
		checkpoints = {},
	}
end

-- LZB part of path_invalidate_ahead. Clears all checkpoints that are ahead of start_idx
-- in contrast to path_inv_ahead, doesn't complain if start_idx is behind train.index, clears everything then
function advtrains.lzb_invalidate_ahead(train, start_idx)
	--advtrains.atprint_context_tid = train.id
	--atprint("LZB: invalidate ahead i=",start_idx)
	if train.lzb then
		local idx = atfloor(start_idx)
		--atprint("LZB: invalidate ahead p=",train.path[start_idx])
		local i = 1
		while train.lzb.checkpoints[i] do
			if train.lzb.checkpoints[i].index >= idx then
				table.remove(train.lzb.checkpoints, i)
			else
				i=i+1
			end
		end
		train.lzb.trav_index = idx
		-- FIX reset trav_lzbdata (look_ahead fetches these when required)
		train.lzb.trav_lzbdata = nil
		-- re-apply all checkpoints to path_speed
		train.path_speed = {}
		train.lzb.zero_checkpoint = false
		for _,ckp in ipairs(train.lzb.checkpoints) do
			apply_checkpoint_to_path(train, ckp)
		end
	end
	--advtrains.atprint_context_tid = nil
end

-- Add LZB control point
-- lzbdata: If you modify lzbdata in an approach callback, you MUST add a checkpoint AND pass the (modified) lzbdata into it.
-- If you DON'T modify lzbdata, you MUST pass nil as lzbdata. Always modify the lzbdata table in place, never overwrite it!
-- udata: user-defined data, do not use externally
function advtrains.lzb_add_checkpoint(train, index, speed, callback, lzbdata, udata)
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
		udata = udata,
	}
	table.insert(lzb.checkpoints, ckp)
	
	apply_checkpoint_to_path(train, ckp)
end


advtrains.te_register_on_new_path(function(id, train)
	advtrains.lzb_invalidate(train)
	-- Taken care of in pre-move hook (see train_step_b)
	--look_ahead(id, train)
end)

advtrains.te_register_on_invalidate_ahead(function(id, train, start_idx)
	advtrains.lzb_invalidate_ahead(train, start_idx)
end)

advtrains.te_register_on_update(function(id, train)
	if not train.path or not train.lzb then
		atprint("LZB run: no path on train, skip step")
		return
	end
	-- Note: look_ahead called from train_step_b before applying movement
	-- TODO: if more pre-move hooks are added, make a separate callback hook
	--look_ahead(id, train)
	call_runover_callbacks(id, train)
end, true)
