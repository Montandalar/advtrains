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
	local ft, ht = advtrains.hud_train_format(train, flip)
	advtrains.set_trainhud(pname, inside.."\n"..ft, ht)
end
function advtrains.clear_driver_hud(pname)
	advtrains.set_trainhud(pname, "")
end

function advtrains.set_trainhud(name, text, driver)
	local hud = advtrains.hud[name]
	local player=minetest.get_player_by_name(name)
	if not player then
	   return
	end
	local driverhud = {
		hud_elem_type = "image",
		name = "ADVTRAINS_DRIVER",
		position = {x=0.5, y=0.7},
		offset = {x=0,y=5},
		text = driver or "advtrains_hud_blank.png",
		alignment = {x=0,y=1},
		scale = {x=1,y=1},}
	if not hud then
		hud = {["driver"]={}}
		advtrains.hud[name] = hud
		hud.id = player:hud_add({
			hud_elem_type = "text",
			name = "ADVTRAINS",
			number = 0xFFFFFF,
			position = {x=0.5, y=0.7},
			offset = {x=0, y=-5},
			text = text,
			scale = {x=200, y=60},
			alignment = {x=0, y=-1},
		})
		hud.oldText=text
		hud.driver = player:hud_add(driverhud)
	else
		if hud.oldText ~= text then
			player:hud_change(hud.id, "text", text)
			hud.oldText=text
		end
		if hud.driver then
			player:hud_change(hud.driver, "text", driver or "advtrains_hud_blank.png")
		elseif driver then
			hud.driver = player:hud_add(driverhud)
		end
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
	if not train then return "" end
	
	local max = train.max_speed or 10
	local res = train.speed_restriction
	local vel = advtrains.abs_ceil(train.velocity)
	local vel_kmh=advtrains.abs_ceil(advtrains.ms_to_kmh(train.velocity))
	
	local levers = {
		[0] = "advtrains_hud_red.png^advtrains_hud_emg.png",
		"advtrains_hud_orange.png^advtrains_hud_b2.png",
		"advtrains_hud_orange.png^advtrains_hud_b1.png",
		"advtrains_hud_gray.png^advtrains_hud_n.png",
		"advtrains_hud_blue.png^advtrains_hud_p.png"}
	local tlev=train.lever
	if train.velocity==0 and not train.active_control then tlev=1 end
	
	local st = {}
	if train.debug then st = {train.debug} end
	
	local ht = ("[combine:100x110:0,0=(%s):50,0=(%s):0,22=(%s):50,22=(%s):0,44=(%s):50,44=(%s):0,66=advtrains_hud_speed_bg.png"
		..":%d,77=(advtrains_hud_speed_ind.png%s)"):format(
		("advtrains_hud_blue.png^advtrains_hud_%s.png"):format(flip and "r" or "f"),
		levers[tlev or 32767] or "advtrains_hud_gray.png^advtrains_hud_na.png",
		(train.tarvelocity or train.atc_command)
			and "advtrains_hud_blue.png^advtrains_hud_atc.png"
			or (train.ctrl.lzb and "advtrains_hud_red.png^advtrains_hud_lzb.png" or "advtrains_hud_gray.png^advtrains_hud_man.png"),
		train.is_shunt and "advtrains_hud_orange.png^advtrains_hud_shunt.png" or "advtrains_hud_gray.png^advtrains_hud_shunt.png",
		train.door_open == -1 and "advtrains_hud_blue.png^advtrains_hud_l_right.png" or "advtrains_hud_gray.png^advtrains_hud_l_right.png",
		train.door_open == 1 and "advtrains_hud_blue.png^advtrains_hud_r.png" or "advtrains_hud_gray.png^advtrains_hud_r.png",
		vel*4.85, (res and res>=0) and "" or "^[resize\\:3x22")
	local si = {}
	if max < 20 then
		si[#si+1] = ("%d,77=(advtrains_hud_speed_max.png^[resize\\:%dx22)"):format(max*5,100-max*5)
	end
	if res and res>=0 then
		si[#si+1] = ("%d,88=advtrains_hud_speed_limit.png"):format(res*4.85)
	end
	if train.tarvelocity then
		si[#si+1] = ("%d,66=advtrains_hud_speed_atc.png"):format(train.tarvelocity*4.85)
	end
	local lzb = train.lzb
	if lzb and lzb.oncoming then
		for i = 1, #lzb.oncoming do
			local k = lzb.oncoming[i]
			if k.spd and k.spd >= 0 then
				si[#si+1] = ("%d,102=advtrains_hud_speed_next.png"):format(k.spd*4.85)
				break
			end
		end
	end
	
	if res and res == 0 then
		st[#st+1] = attrans("OVERRUN RED SIGNAL! Examine situation and reverse train to move again.")
	end
	
	if train.atc_command then
		st[#st+1] = ("ATC: %s%s"):format(train.atc_delay and advtrains.abs_ceil(train.atc_delay).."s " or "", train.atc_command or "")
	end
	
	return table.concat(st,"\n"), #si>0 and ht..":"..table.concat(si,":") or ht
end
