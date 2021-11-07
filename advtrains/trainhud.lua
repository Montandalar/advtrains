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
			train.ctrl_user = 1
			act=true
		end
		-- If atc command set, only "Jump" key can clear command. To prevent accidental control.
		if train.tarvelocity or train.atc_command then
			return
		end
		if pc.up then
		   train.ctrl_user=4
		   act=true
		end
		if pc.down then
			if train.velocity>0 then
				if pc.jump then
					train.ctrl_user = 0
				else
					train.ctrl_user = 2
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
			train.ctrl_user = nil
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
		position = {x=0.5, y=1},
		offset = {x=0,y=-170},
		text = driver or "",
		alignment = {x=0,y=-1},
		scale = {x=1,y=1},}
	if not hud then
		hud = {["driver"]={}}
		advtrains.hud[name] = hud
		hud.id = player:hud_add({
			hud_elem_type = "text",
			name = "ADVTRAINS",
			number = 0xFFFFFF,
			position = {x=0.5, y=1},
			offset = {x=0, y=-300},
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
	if not train then return "","" end
	local sformat = string.format -- this appears to be faster than (...):format
	
	local max = train.max_speed or 10
	local res = train.speed_restriction
	local vel = advtrains.abs_ceil(train.velocity)
	local vel_kmh=advtrains.abs_ceil(advtrains.ms_to_kmh(train.velocity))
	
	local tlev=train.lever or 1
	if train.velocity==0 and not train.active_control then tlev=1 end
	if train.hud_lzb_effect_tmr then
		tlev=1
	end
	
	local ht = {"[combine:440x110:0,0=(advtrains_hud_bg.png^[resize\\:440x110)"}
	local st = {}
	if train.debug then st = {train.debug} end
	
	-- seven-segment display
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
				ht[#ht+1] = sformat("%d,%d=(advtrains_hud_bg.png^[resize\\:%dx%d^%s)",x+s[1], y+s[2], s[3], s[4], m)
			end
		end
	end
	
	-- lever
	ht[#ht+1] = "275,10=(advtrains_hud_bg.png^[colorize\\:cyan^[resize\\:5x18)"
	ht[#ht+1] = "275,28=(advtrains_hud_bg.png^[colorize\\:white^[resize\\:5x18)"
	ht[#ht+1] = "275,46=(advtrains_hud_bg.png^[colorize\\:orange^[resize\\:5x36)"
	ht[#ht+1] = "275,82=(advtrains_hud_bg.png^[colorize\\:red^[resize\\:5x18)"
	ht[#ht+1] = "292,16=(advtrains_hud_bg.png^[colorize\\:darkslategray^[resize\\:6x78)"
	ht[#ht+1] = sformat("280,%s=(advtrains_hud_bg.png^[colorize\\:gray^[resize\\:30x18)",18*(4-tlev)+10)
	-- reverser
	ht[#ht+1] = sformat("245,10=(advtrains_hud_arrow.png^[transformFY%s)", flip and "" or "^[multiply\\:cyan")
	ht[#ht+1] = sformat("245,85=(advtrains_hud_arrow.png%s)", flip and "^[multiply\\:orange" or "")
	ht[#ht+1] = "250,35=(advtrains_hud_bg.png^[colorize\\:darkslategray^[resize\\:5x40)"
	ht[#ht+1] = sformat("240,%s=(advtrains_hud_bg.png^[resize\\:25x15^[colorize\\:gray)", flip and 65 or 30)
	-- train control/safety indication
	if train.tarvelocity or train.atc_command then
		ht[#ht+1] = "10,10=(advtrains_hud_atc.png^[resize\\:30x30^[multiply\\:cyan)"
	end
	if train.hud_lzb_effect_tmr then
		ht[#ht+1] = "50,10=(advtrains_hud_lzb.png^[resize\\:30x30^[multiply\\:red)"
	end
	if train.is_shunt then
		ht[#ht+1] = "90,10=(advtrains_hud_shunt.png^[resize\\:30x30^[multiply\\:orange)"
	end
	-- door
	ht[#ht+1] = "187,10=(advtrains_hud_bg.png^[resize\\:26x30^[colorize\\:white)"
	ht[#ht+1] = "189,12=(advtrains_hud_bg.png^[resize\\:22x11)"
	ht[#ht+1] = sformat("170,10=(advtrains_hud_bg.png^[resize\\:15x30^[colorize\\:%s)", train.door_open==-1 and "white" or "darkslategray")
	ht[#ht+1] = "172,12=(advtrains_hud_bg.png^[resize\\:11x11)"
	ht[#ht+1] = sformat("215,10=(advtrains_hud_bg.png^[resize\\:15x30^[colorize\\:%s)", train.door_open==1 and "white" or "darkslategray")
	ht[#ht+1] = "217,12=(advtrains_hud_bg.png^[resize\\:11x11)"
	-- speed indication(s)
	sevenseg(math.floor(vel/10), 320, 10, 30, 10, "[colorize\\:red\\:255")
	sevenseg(vel%10, 380, 10, 30, 10, "[colorize\\:red\\:255")
	for i = 1, vel, 1 do
		ht[#ht+1] = sformat("%d,65=(advtrains_hud_bg.png^[resize\\:8x20^[colorize\\:white)", i*11-1)
	end
	for i = max+1, 20, 1 do
		ht[#ht+1] = sformat("%d,65=(advtrains_hud_bg.png^[resize\\:8x20^[colorize\\:darkslategray)", i*11-1)
	end
	if res and res > 0 then
		ht[#ht+1] = sformat("%d,60=(advtrains_hud_bg.png^[resize\\:3x30^[colorize\\:red\\:255)", 7+res*11)
	end
	if train.tarvelocity then
		ht[#ht+1] = sformat("%d,85=(advtrains_hud_arrow.png^[multiply\\:cyan^[transformFY^[makealpha\\:#000000)", 1+train.tarvelocity*11)
	end
	local lzb = train.lzb
	if lzb and lzb.checkpoints then
		local oc = lzb.checkpoints
		for i = 1, #oc do
			local spd = oc[i].speed
			spd = advtrains.speed.min(spd, train.speed_restriction)
			if spd == -1 then spd = nil end
			local c = not spd and "lime" or (type(spd) == "number" and (spd == 0) and "red" or "orange") or nil
			if c then
				ht[#ht+1] = sformat("130,10=(advtrains_hud_bg.png^[resize\\:30x5^[colorize\\:%s)",c)
				ht[#ht+1] = sformat("130,35=(advtrains_hud_bg.png^[resize\\:30x5^[colorize\\:%s)",c)
				if spd and spd~=0 then
					ht[#ht+1] = sformat("%d,50=(advtrains_hud_arrow.png^[multiply\\:red^[makealpha\\:#000000)", 1+spd*11) 
				end
				local floor = math.floor
				local dist = floor(((oc[i].index or train.index)-train.index))
				dist = math.max(0, math.min(999, dist))
				for j = 1, 3, 1 do
					sevenseg(floor((dist/10^(3-j))%10), 119+j*11, 18, 4, 2, "[colorize\\:"..c)
				end
				break
			end
		end
	end
	
	if res and res == 0 then
		st[#st+1] = attrans("OVERRUN RED SIGNAL! Examine situation and reverse train to move again.")
	end
	
	if train.atc_command then
			st[#st+1] = sformat("ATC: %s%s", train.atc_delay and advtrains.abs_ceil(train.atc_delay).."s " or "", train.atc_command or "")
	end
	
	return table.concat(st,"\n"), table.concat(ht,":")
end

local _, texture = advtrains.hud_train_format { -- dummy train object to demonstrate the train hud
	max_speed = 15, speed_restriction = 15, velocity = 15, tarvelocity = 12,
	active_control = true, lever = 3, ctrl = {lzb = true}, is_shunt = true,
	door_open = 1, lzb = {oncoming = {{spd=6, idx=125.7}}}, index = 0,
}

minetest.register_node("advtrains:hud_demo",{
	description = "Train HUD demonstration",
	tiles = {texture},
	groups = {cracky = 3, not_in_creative_inventory = 1}
})

minetest.register_craft {
	output = "advtrains:hud_demo",
	recipe = {
		{"default:paper", "default:paper", "default:paper"},
		{"default:paper", "advtrains:trackworker", "default:paper"},
		{"default:paper", "default:paper", "default:paper"},
	}
}
