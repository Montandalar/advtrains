-- lzb.lua
-- Enforced and/or automatic train override control, obeying signals


local function approach_callback(parpos, train_id, train, index)
	local pos = advtrains.round_vector_floor_y(parpos)
	
	local node=pnode or advtrains.ndb.get_node(pos)
	local ndef=minetest.registered_nodes[node.name]
	if ndef and ndef.advtrains and ndef.advtrains.on_train_approach then
		ndef.advtrains.on_train_approach(pos, train_id, train, index)
	end
end


--[[
Documentation of train.lzb table
train.lzb = {
	trav = Current index that the traverser has advanced so far
	travsht = boolean indicating whether the train will be a shunt move at "trav"
	travspd = speed restriction at end of traverser
	travwspd = warning speed res.
	oncoming = table containing oncoming signals, in order of appearance on the path
		{
			pos = position of the signal (not the IP!). Can be nil
			idx = where this is on the path
			spd = speed allowed to pass (determined dynamically)
			npr = <boolean> "No permanent restriction" If true, this is only a punctual restriction.
				speed_restriction is not set then, and train can accelerate after passing point
				This is (as of Nov 2017) used by "lines" to brake the train down to 2 when approaching a stop
				The actual "stop" command is given when the train passes the rail (on_train_enter callback)
		}
}
each step, for every item in "oncoming", we need to determine the location to start braking (+ some safety margin)
and, if we passed this point for at least one of the items, initiate brake.
When speed has dropped below, say 3, decrease the margin to zero, so that trains actually stop at the signal IP.
The spd variable and travsht need to be updated on every aspect change. it's probably best to reset everything when any aspect changes

The traverser stops at signals that result in spd==0, because changes beyond there are likely.
]]

local il = advtrains.interlocking

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

function advtrains.interlocking.set_lzb_param(par, val)
	if params[par] and tonumber(val) then
		params[par] = tonumber(val)
	else
		error("Inexistant param or not a number")
	end
end


local function look_ahead(id, train)
	
	local acc = advtrains.get_acceleration(train, 1)
	local vel = train.velocity
	local brakedst = ( -(vel*vel) / (2*acc) ) * params.DST_FACTOR
	
	local brake_i = advtrains.path_get_index_by_offset(train, train.index, brakedst + params.BRAKE_SPACE)
	--local aware_i = advtrains.path_get_index_by_offset(train, brake_i, AWARE_ZONE)
	
	local lzb = train.lzb
	local trav = lzb.trav
	local travspd = lzb.travspd
	local travwspd = lzb.travwspd
	local lspd
	
	--train.debug = lspd
	
	while trav <= brake_i and (not lspd or lspd>0) do
		trav = trav + 1
		local pos = advtrains.path_get(train, trav)
		local pts = advtrains.roundfloorpts(pos)
		local cn  = train.path_cn[trav]
		-- check offtrack
		if trav > train.path_trk_f then
			lspd = 0
			table.insert(lzb.oncoming, {
				idx = trav-1,
				spd = 0,
			})
		else
			-- run callback, if exists
			approach_callback(pos, id, train, trav)
			
			-- check for signal
			local asp, spos = il.db.get_ip_signal_asp(pts, cn)
			
			-- do ARS if needed
			if spos then
				local sigd = il.db.get_sigd_for_signal(spos)
				if sigd then
					il.ars_check(sigd, train)
				end
			end
			--atdebug("trav: ",pos, cn, asp, spos, "travsht=", lzb.travsht)
			if asp then
				local nspd = 0
				--interpreting aspect and determining speed to proceed
				if lzb.travsht then
					--shunt move
					if asp.shunt.free then
						nspd = params.SHUNT_SPEED_MAX
					elseif asp.shunt.proceed_as_main and asp.main.free then
						nspd = asp.main.speed
						lzb.travsht = false
					end
				else
					--train move
					if asp.main.free then
						nspd = asp.main.speed
					elseif asp.shunt.free then
						nspd = params.SHUNT_SPEED_MAX
						lzb.travsht = true
					end
				end
				-- nspd can now be: 1. !=0: new speed restriction, 2. =0: stop here or 3. nil: keep travspd
				if nspd then
					if nspd == -1 then
						travspd = nil
					else
						travspd = nspd
					end
				end
				
				local nwspd = asp.info.w_speed
				if nwspd then
					if nwspd == -1 then
						travwspd = nil
					else
						travwspd = nwspd
					end
				end
				--atdebug("ns,wns,ts,wts", nspd, nwspd, travspd, travwspd)
				lspd = travspd
				if travwspd and (not lspd or lspd>travwspd) then
					lspd = travwspd
				end
				
				table.insert(lzb.oncoming, {
					pos = spos,
					idx = trav,
					spd = lspd,
					sht = lzb.travsht,
				})
			end
		end
	end
	
	lzb.trav = trav
	lzb.travspd = travspd
	lzb.travwspd = travwspd
	
	--train.debug = dump(lzb)
	
end

--[[
Distance needed to accelerate from v0 to v1 with constant acceleration a:

         v1 - v0     a   / v1 - v0 \ 2
s = v0 * -------  +  - * | ------- |
            a        2   \    a    /
]]

local function apply_control(id, train)
	local lzb = train.lzb
	
	local i = 1
	while i<=#lzb.oncoming do
		if lzb.oncoming[i].idx < train.index-0.5 then
			if not lzb.oncoming[i].npr then
				train.speed_restriction = lzb.oncoming[i].spd
				train.is_shunt = lzb.oncoming[i].sht
			end
			table.remove(lzb.oncoming, i)
		else
			i = i + 1
		end
	end
	
	for i, it in ipairs(lzb.oncoming) do
		local a = advtrains.get_acceleration(train, 1) --should be negative
		local v0 = train.velocity
		local v1 = it.spd
		if v1 and v1 <= v0 then
			local f = (v1-v0) / a
			local s = v0*f + a*f*f/2
			
			local st = s + params.ADD_SLOW
			if v0 > 3 then
				st = s + params.ADD_FAST
			end
			if v0<=0 then
				st = s + params.ADD_STAND
			end
			
			local i = advtrains.path_get_index_by_offset(train, it.idx, -st)
			
			--train.debug = dump({v0f=v0*f, aff=a*f*f,v0=v0, v1=v1, f=f, a=a, s=s, st=st, i=i, idx=train.index})
			if i <= train.index then
				-- Gotcha! Braking...
				train.ctrl.lzb = 1
				--train.debug = train.debug .. "BRAKE!!!"
				return
			end
			
			i = advtrains.path_get_index_by_offset(train, i, -params.ZONE_ROLL)
			if i <= train.index and v0>1 then
				-- roll control
				train.ctrl.lzb = 2
				return
			end
			i = advtrains.path_get_index_by_offset(train, i, -params.ZONE_HOLD)
			if i <= train.index and v0>1 then
				-- hold speed
				train.ctrl.lzb = 3
				return
			end
		end
	end
	train.ctrl.lzb = nil
end

local function invalidate(train)
	train.lzb = {
		trav = atfloor(train.index),
		travsht = train.is_shunt,
		oncoming = {}
	}
	train.ctrl.lzb = nil
end

function advtrains.interlocking.lzb_invalidate(train)
	invalidate(train)
end

-- Add an (extra) lzb control point that is not a permanent restriction (see above)
-- (permanent restrictions are only to be imposed by signal ip's)
function advtrains.interlocking.lzb_add_oncoming_npr(train, idx, spd)
	local lzb = train.lzb
	
	table.insert(lzb.oncoming, {
					idx = idx,
					spd = spd,
					npr = true,
				})
end


advtrains.te_register_on_new_path(function(id, train)
	invalidate(train)
	look_ahead(id, train)
end)

advtrains.te_register_on_update(function(id, train)
	if not train.path or not train.lzb then
		atprint("LZB run: no path on train, skip step")
		return
	end
	look_ahead(id, train)
	apply_control(id, train)
end)
