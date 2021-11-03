-- Interlocking counterpart of LZB, which has been moved into the core...
-- Registers LZB callback for signal management.

--[[
usage of lzbdata:
{
	travsht = boolean indicating whether the train will be a shunt move at "trav"
	travspd = speed restriction at end of traverser
	travwspd = warning speed res.t
}
]]

local SHUNT_SPEED_MAX = advtrains.SHUNT_SPEED_MAX

local il = advtrains.interlocking

local function get_over_function(speed, shunt, asptype)
	return function(pos, id, train, index, speed, lzbdata)
		if speed == 0 and minetest.settings:get_bool("at_il_force_lzb_halt") then
			atwarn(id,"overrun LZB 0 restriction (red signal) ",pos)
			-- Set train 1 index backward. Hope this does not lead to bugs...
			--train.index = index - 0.5
			advtrains.speed.set_restriction(train, "main", 0)
			
			--TODO temporary
			--advtrains.drb_dump(id)
			--error("Debug: "..id.." triggered LZB-0")
		else
			advtrains.speed.set_restriction(train, asptype, speed or -1)
			train.is_shunt = shunt
		end
		--atdebug("train drove over IP: speed=",speed,"shunt=",shunt)
	end
end

advtrains.tnc_register_on_approach(function(pos, id, train, index, has_entered, lzbdata)

	--atdebug(id,"IL ApprC",pos,index,lzbdata)
	--train.debug = advtrains.print_concat_table({train.is_shunt,"|",index,"|",lzbdata})

	local pts = advtrains.roundfloorpts(pos)
	local cn  = train.path_cn[index]
	local travsht = lzbdata.il_shunt
	
	local travspd = lzbdata.il_speed
	
	if travsht==nil then
		-- lzbdata has reset
		travspd = train.speed_restriction
		travsht = train.is_shunt or false
	end
	
	
	
	-- check for signal
	local asp, spos = il.db.get_ip_signal_asp(pts, cn)
	
	-- do ARS if needed
	local ars_enabled = not train.ars_disable
	-- Note on ars_disable:
	-- Theoretically, the ars_disable flag would need to behave like the speed restriction field: it should be
	-- stored in lzbdata and updated once the train drives over. However, for the sake of simplicity, it is simply
	-- a value in the train. In this case, this is sufficient because once a train triggers ARS for the first time,
	-- resetting the path does not matter to the set route and ARS doesn't need to be called again.
	if spos and ars_enabled then
		--atdebug(id,"IL Spos (ARS)",spos,asp)
		local sigd = il.db.get_sigd_for_signal(spos)
		if sigd then
			il.ars_check(sigd, train)
		end
	end
	--atdebug("trav: ",pos, cn, asp, spos, "travsht=", lzb.travsht)
	local lspd
	if asp then
		--atdebug(id,"IL Signal",spos, asp, lzbdata, "trainstate", train.speed_restriction, train.is_shunt)
		local nspd = 0
		--interpreting aspect and determining speed to proceed
		if travsht then
			--shunt move
			if asp.shunt then
				nspd = SHUNT_SPEED_MAX
			elseif asp.proceed_as_main and asp.main ~= 0 then
				nspd = asp.main
				travsht = false
			end
		else
			--train move
			if asp.main ~= 0 then
				nspd = asp.main
			elseif asp.shunt then
				nspd = SHUNT_SPEED_MAX
				travsht = true
			end
		end
		-- nspd can now be: 1. !=0: new speed restriction, 2. =0: stop here or 3. nil: keep travspd
		if nspd then
			travspd = nspd
			if nspd == -1 then
				travspd = nil
			else
				travspd = nspd
			end
		end
		
		--atdebug("ns,ts", nspd, travspd)

		lspd = travspd
		
		local udata = {signal_pos = spos}
		local callback = get_over_function(lspd, travsht, asp.type)
		lzbdata.il_shunt = travsht
		lzbdata.il_speed = travspd
		--atdebug("new lzbdata",lzbdata)
		advtrains.lzb_add_checkpoint(train, index, lspd, callback, lzbdata, udata)
	end
end)

-- Set the ars_disable flag to the value passed
-- Triggers a path invalidation if set to false
function advtrains.interlocking.ars_set_disable(train, value)
	if value then
		train.ars_disable = true
	else
		train.ars_disable = nil
		minetest.after(0, advtrains.path_invalidate, train)
	end
end
