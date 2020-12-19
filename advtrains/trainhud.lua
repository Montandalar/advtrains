--trainhud.lua: holds all the code for train controlling

advtrains.hud = {}
advtrains.hhud = {}

minetest.register_on_leaveplayer(function(player)
advtrains.hud[player:get_player_name()] = nil
advtrains.hhud[player:get_player_name()] = nil
end)

local mletter={[1]="F", [-1]="R", [0]="N"}

function advtrains.on_control_change(pc, train, flip)
   	local maxspeed = train.max_speed or 10
	if pc.sneak then
		if pc.up then
			train.tarvelocity = maxspeed
		end
		if pc.down then
			train.tarvelocity = 0
		end
		if pc.left then
			train.tarvelocity = 4
		end
		if pc.right then
			train.tarvelocity = 8
		end
		--[[if pc.jump then
			train.brake = true
			--0: released, 1: brake and pressed, 2: released and brake, 3: pressed and brake
			if not train.brake_hold_state or train.brake_hold_state==0 then
				train.brake_hold_state = 1
			elseif train.brake_hold_state==2 then
				train.brake_hold_state = 3
			end
		elseif train.brake_hold_state==1 then
			train.brake_hold_state = 2
		elseif train.brake_hold_state==3 then
			train.brake = false
			train.brake_hold_state = 0
		end]]
		--shift+use:see wagons.lua
	else
		local act=false
		if pc.jump then
			train.ctrl.user = 1
			act=true
		end
		-- If atc command set, only "Jump" key can clear command. To prevent accidental control.
		if train.tarvelocity or train.atc_command then
			return
		end
		if pc.up then
		   train.ctrl.user=4
		   act=true
		end
		if pc.down then
			if train.velocity>0 then
				if pc.jump then
					train.ctrl.user = 0
				else
					train.ctrl.user = 2
				end
				act=true
			else
				advtrains.invert_train(train.id)
				advtrains.atc.train_reset_command(train)
			end
		end
		if pc.left then
			if train.door_open ~= 0 then
				train.door_open = 0
			else
				train.door_open = -1
			end
		end
		if pc.right then
			if train.door_open ~= 0 then
				train.door_open = 0
			else
				train.door_open = 1
			end
		end
		if not act then
			train.ctrl.user = nil
		end
	end
end
function advtrains.update_driver_hud(pname, train, flip)
	local inside=train.text_inside or ""
	advtrains.set_trainhud(pname, inside.."\n"..advtrains.hud_train_format(train, flip))
end
function advtrains.clear_driver_hud(pname)
	advtrains.set_trainhud(pname, "")
end

function advtrains.set_trainhud(name, text)
	local hud = advtrains.hud[name]
	local player=minetest.get_player_by_name(name)
	if not player then
	   return
	end
	if not hud then
		hud = {}
		advtrains.hud[name] = hud
		hud.id = player:hud_add({
			hud_elem_type = "text",
			name = "ADVTRAINS",
			number = 0xFFFFFF,
			position = {x=0.5, y=0.7},
			offset = {x=0, y=0},
			text = text,
			scale = {x=200, y=60},
			alignment = {x=0, y=0},
		})
		hud.oldText=text
		return
	elseif hud.oldText ~= text then
		player:hud_change(hud.id, "text", text)
		hud.oldText=text
	end
end
function advtrains.set_help_hud(name, text)
	local hud = advtrains.hhud[name]
	local player=minetest.get_player_by_name(name)
	if not player then
	   return
	end
	if not hud then
		hud = {}
		advtrains.hhud[name] = hud
		hud.id = player:hud_add({
			hud_elem_type = "text",
			name = "ADVTRAINS_HELP",
			number = 0xFFFFFF,
			position = {x=1, y=0.3},
			offset = {x=0, y=0},
			text = text,
			scale = {x=200, y=60},
			alignment = {x=1, y=0},
		})
		hud.oldText=text
		return
	elseif hud.oldText ~= text then
		player:hud_change(hud.id, "text", text)
		hud.oldText=text
	end
end

--train.lever:
--Speed control lever in train, for new train control system.
--[[
Value	Disp	Control	Meaning
0		BB		S+Space	Emergency Brake
1		B		Space	Normal Brake
2		-		S		Roll
3		o		<none>	Stay at speed
4		+		W		Accelerate
]]

function advtrains.hud_train_format(train, flip)
	local fct=flip and -1 or 1
	if not train then return "" end
	
	local max = train.max_speed or 10
	local res = train.speed_restriction
	local vel = advtrains.abs_ceil(train.velocity)
	local vel_kmh=advtrains.abs_ceil(advtrains.ms_to_kmh(train.velocity))
	
	local levers = {[0] = "EMG", "B 2", "B 1", " N ", " P "}
	local tlev=train.lever
	if train.velocity==0 and not train.active_control then tlev=1 end
	
	local doorstr = function(side, open)
		return (open and "<%s>" or ">%s<"):format(side)
	end
	
	local topLine, firstLine
	local st = {}
	if train.debug then st = {train.debug} end
	
	st[#st+1] = ("[%s] [%s] [%s %s]%s [%s]"):format(
		mletter[fct],
		levers[tlev] or "N/A",
		doorstr("L", train.door_open==-1),
		doorstr("R", train.door_open==1),
		train.is_shunt and " [SHUNT]" or "",
		(train.tarvelocity or train.atc_command) and "ATC" or (train.ctrl.lzb and "LZB" or "MAN"))
	
	local velstr = function(vel, name)
		return ("%s%02d m/s (%02d km/h)"):format(
			name and (attrans(name).." ") or "",vel,advtrains.ms_to_kmh(vel))
	end
	st[#st+1] = velstr(vel, "Speed:")
	if max then st[#st+1] = velstr(max, "Max. Speed:") end
	if res then st[#st+1] = res == 0
		and attrans("OVERRUN RED SIGNAL! Examine situation and reverse train to move again.")
		or velstr(res, "Restriction:") end
	
	if train.tarvelocity or train.atc_command then
		st[#st+1] = ("ATC: %s%s%s"):format(
			train.tarvelocity and (velstr(train.tarvelocity).." ") or "",
			train.atc_delay and advtrains.abs_ceil(train.atc_delay).."s " or "",
			train.atc_command or "")
	end

	local lzb = train.lzb
	
	local i = 1
	while i<=#lzb.oncoming do
		local k = lzb.oncoming[i]
		st[#st+1] = "LZB: speed limit ["..(k.spd or "E")..("] in %.1f m"):format(k.idx-train.index)
		if k.spd == 0 then
			break
		end
		i=i+1
	end

	
	return table.concat(st,"\n")
end
