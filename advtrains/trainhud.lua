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
			player:hud_change(hud.driver, "text", driver or "")
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
	
	local levers = {[0] = "emg","b","r","n","p"}
	local lvrcolor = {[0] = "red", "orange", "orange", "cyan", "cyan"}
	local tlev=train.lever or 1
	if train.velocity==0 and not train.active_control then tlev=1 end
	
	local st = {}
	if train.debug then st = {train.debug} end
	
	local ht = {"[combine:300x150:0,0=(advtrains_hud_bg.png^[resize\\:300x150)"}
	ht[#ht+1] = "100,0=(advtrains_hud_" .. (flip and "reverse" or "forward") .. ".png^[resize\\:100x20)"
	ht[#ht+1] = "200,0=(advtrains_hud_" .. (levers[tlev] or "bg") .. ".png^[resize\\:100x20^[multiply\\:" .. (lvrcolor[tlev] or "#000000") .. ")"
	if train.tarvelocity or train.atc_command then
		ht[#ht+1] = "100,20=(advtrains_hud_atc.png^[resize\\:100x20)"
	end
	if train.ctrl.lzb then
		ht[#ht+1] = "200,20=(advtrains_hud_lzb.png^[resize\\:100x20^[multiply\\:red)"
	end
	if train.is_shunt then
		ht[#ht+1] = "100,40=(advtrains_hud_shunt.png^[resize\\:100x20)"
	end
	if train.door_open == -1 then
		ht[#ht+1] = "100,60=(advtrains_hud_left_door.png^[resize\\:100x20)"
	elseif train.door_open == 1 then
		ht[#ht+1] = "200,60=(advtrains_hud_right_door.png^[resize\\:100x24)"
	end
	-- speed indication(s)
	local function sevenseg(digit, x, y, w, h, m)
		--[[
		 -1-
		2   3
		 -4-
		5   6
		 -7-
		]]
		local segs = {
			{h, 0, w, h},
			{0, h, h, w},
			{w+h, h, h, w},
			{h, w+h, w, h},
			{0, w+2*h, h, w},
			{w+h, w+2*h, h, w},
			{h, 2*(w+h), w, h}}
		local trans = {
			[0] = {true, true, true, false, true, true, true},
			[1] = {false, false, true, false, false, true, false},
			[2] = {true, false, true, true, true, false, true},
			[3] = {true, false, true, true, false, true, true},
			[4] = {false, true, true, true, false, true, false},
			[5] = {true, true, false, true, false, true, true},
			[6] = {true, true, false, true, true, true, true},
			[7] = {true, false, true, false, false, true, false},
			[8] = {true, true, true, true, true, true, true},
			[9] = {true, true, true, true, false, true, true}}
		local ent = trans[digit or 10]
		if not ent then return end
		for i = 1, 7, 1 do
			if ent[i] then
				local s = segs[i]
				ht[#ht+1] = ("%d,%d=(advtrains_hud_bg.png^[resize\\:%dx%d^%s)"):format(x+s[1], y+s[2], s[3], s[4], m)
			end
		end
	end
	sevenseg(math.floor(vel/10), 5, 5, 20, 10, "[colorize\\:red\\:255")
	sevenseg(vel%10, 55, 5, 20, 10, "[colorize\\:red\\:255")
	ht[#ht+1] = ("10,100=(advtrains_hud_bg.png^[resize\\:%dx30^[colorize\\:white\\:255)"):format(vel*14)
	if max < 20 then
		ht[#ht+1] = ("%d,100=(advtrains_hud_bg.png^[resize\\:%dx30^[colorize\\:gray\\:255)"):format(10+max*14, 280-max*14)
	end
	if res and res > 0 then
		ht[#ht+1] = ("%d,95=(advtrains_hud_bg.png^[resize\\:3x40^[colorize\\:red\\:255)"):format(8+res*14)
	end
	if train.tarvelocity then
		ht[#ht+1] = ("%d,130=(advtrains_hud_arrow.png^[multiply\\:cyan^[transformFY)"):format(2+train.tarvelocity*14)
	end
	local lzb = train.lzb
	if lzb and lzb.oncoming then
		for i = 1, #lzb.oncoming do
			local k = lzb.oncoming[i]
			if not k.spd then
				ht[#ht+1] = "203,43=(advtrains_hud_bg.png^[resize\\:14x14^[colorize\\:lime\\:255)"
			elseif k.spd == 0 then
				ht[#ht+1] = "283,43=(advtrains_hud_bg.png^[resize\\:14x14^[colorize\\:red\\:255)"
			else
				ht[#ht+1] = "243,43=(advtrains_hud_bg.png^[resize\\:14x14^[colorize\\:orange\\:255)"
				ht[#ht+1] = ("%d,85=(advtrains_hud_arrow.png^[multiply\\:red)"):format(2+k.spd*14) 
			end
			break
		end
	end
	
	if res and res == 0 then
		st[#st+1] = attrans("OVERRUN RED SIGNAL! Examine situation and reverse train to move again.")
	end
	
	if train.atc_command then
		st[#st+1] = ("ATC: %s%s"):format(train.atc_delay and advtrains.abs_ceil(train.atc_delay).."s " or "", train.atc_command or "")
	end
	
	return table.concat(st,"\n"), table.concat(ht,":")
end
