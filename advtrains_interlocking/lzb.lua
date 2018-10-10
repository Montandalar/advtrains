-- lzb.lua
-- Enforced and/or automatic train override control, obeying signals

--[[
Documentation of train.lzb table
train.lzb = {
	trav = Current index that the traverser has advanced so far
	travsht = boolean indicating whether the train will be a shunt move at "trav"
	travspd = speed restriction at end of traverser
	travwspd = warning speed res.
	oncoming = table containing oncoming signals, in order of appearance on the path
		{
			pos = position of the signal (not the IP!)
			idx = where this is on the path
			spd = speed allowed to pass (determined dynamically)
		}
}
each step, for every item in "oncoming", we need to determine the location to start braking (+ some safety margin)
and, if we passed this point for at least one of the items, initiate brake.
When speed has dropped below, say 3, decrease the margin to zero, so that trains actually stop at the signal IP.
The spd variable and travsht need to be updated on every aspect change. it's probably best to reset everything when any aspect changes

The traverser stops at signals that result in spd==0, because changes beyond there are likely.
]]

local il = advtrains.interlocking

local BRAKE_SPACE = 10
local AWARE_ZONE  = 50

local ADD_STAND  =  2
local ADD_SLOW   =  1
local ADD_FAST   =  10

local SHUNT_SPEED_MAX = 4

local function look_ahead(id, train)
	
	local acc = advtrains.get_acceleration(train, 1)
	local vel = train.velocity
	local brakedst = -(vel*vel) / (2*acc)
	
	local brake_i = advtrains.path_get_index_by_offset(train, train.index, brakedst + BRAKE_SPACE)
	--local aware_i = advtrains.path_get_index_by_offset(train, brake_i, AWARE_ZONE)
	
	local lzb = train.lzb
	local trav = lzb.trav
	local travspd = lzb.travspd
	local travwspd = lzb.travwspd
	local lspd
	
	train.debug = lspd
	
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
			-- check for signal
			local asp, spos = il.db.get_ip_signal_asp(pts, cn)
			--atdebug("trav: ",pos, cn, asp, spos, "travsht=", lzb.travsht)
			if asp then
				local nspd = 0
				--interpreting aspect and determining speed to proceed
				if lzb.travsht then
					--shunt move
					if asp.shunt.free then
						nspd = SHUNT_SPEED_MAX
					elseif asp.shunt.proceed_as_main and asp.main.free then
						nspd = asp.main.speed
						lzb.travsht = false
					end
				else
					--train move
					if asp.main.free then
						nspd = asp.main.speed
					elseif asp.shunt.free then
						nspd = SHUNT_SPEED_MAX
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
				})
				-- TODO register aspect change callback!
			end
		end
	end
	
	lzb.trav = trav
	lzb.travspd = travspd
	lzb.travwspd = travwspd
	
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
	while i<#lzb.oncoming do
		if lzb.oncoming[i].idx < train.index then
			train.speed_restriction = lzb.oncoming[i].spd
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
			
			local st = s + ADD_SLOW
			if v0 > 3 then
				st = s + ADD_FAST
			end
			if v0<=0 then
				st = s + ADD_STAND
			end
			
			local i = advtrains.path_get_index_by_offset(train, it.idx, -st)
			
			--train.debug = dump({v0f=v0*f, aff=a*f*f,v0=v0, v1=v1, f=f, a=a, s=s, st=st, i=i, idx=train.index})
			if i <= train.index then
				-- Gotcha! Braking...
				train.ctrl.lzb = 1
				--train.debug = train.debug .. "BRAKE!!!"
				return
			end
		end
	end
	train.ctrl.lzb = nil
end


advtrains.te_register_on_new_path(function(id, train)
	train.lzb = {
		trav = atfloor(train.index),
		travsht = train.is_shunt,
		oncoming = {}
	}
	train.ctrl.lzb = nil
	look_ahead(id, train)
end)

advtrains.te_register_on_update(function(id, train)
	look_ahead(id, train)
	apply_control(id, train)
end)
