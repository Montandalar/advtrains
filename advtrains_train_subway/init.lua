local S = attrans

advtrains.register_wagon("subway_wagon", {
	mesh="advtrains_subway_wagon.b3d",
	textures = {"advtrains_subway_wagon.png"},
	drives_on={default=true},
	max_speed=15,
	seats = {
		{
			name="Driver stand",
			attach_offset={x=0, y=0, z=0},
			view_offset={x=0, y=0, z=0},
			group="dstand",
		},
		{
			name="1",
			attach_offset={x=-4, y=-2, z=8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="2",
			attach_offset={x=4, y=-2, z=8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="3",
			attach_offset={x=-4, y=-2, z=-8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="4",
			attach_offset={x=4, y=-2, z=-8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
	},
	seat_groups = {
		dstand={
			name = "Driver Stand",
			access_to = {"pass"},
			require_doors_open=true,
			driving_ctrl_access=true,
		},
		pass={
			name = "Passenger area",
			access_to = {"dstand"},
			require_doors_open=true,
		},
	},
	assign_to_seat_group = {"pass", "dstand"},
	doors={
		open={
			[-1]={frames={x=0, y=20}, time=1},
			[1]={frames={x=40, y=60}, time=1},
			sound = "advtrains_subway_dopen",
		},
		close={
			[-1]={frames={x=20, y=40}, time=1},
			[1]={frames={x=60, y=80}, time=1},
			sound = "advtrains_subway_dclose",
		}
	},
	door_entry={-1, 1},
	visual_size = {x=1, y=1},
	wagon_span=2,
	--collisionbox = {-1.0,-0.5,-1.8, 1.0,2.5,1.8},
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	is_locomotive=true,
	drops={"default:steelblock 4"},
	horn_sound = "advtrains_subway_horn",
	custom_on_velocity_change = function(self, velocity, old_velocity, dtime)
		if not velocity or not old_velocity then return end
		if old_velocity == 0 and velocity > 0 then
			minetest.sound_play("advtrains_subway_depart", {object = self.object})
		end
		if velocity < 2 and (old_velocity >= 2 or old_velocity == velocity) and not self.sound_arrive_handle then
			self.sound_arrive_handle = minetest.sound_play("advtrains_subway_arrive", {object = self.object})
		elseif (velocity > old_velocity) and self.sound_arrive_handle then
			minetest.sound_stop(self.sound_arrive_handle)
			self.sound_arrive_handle = nil
		end
		if velocity > 0 and (self.sound_loop_tmr or 0)<=0 then
			self.sound_loop_handle = minetest.sound_play({name="advtrains_subway_loop", gain=0.3}, {object = self.object})
			self.sound_loop_tmr=3
		elseif velocity>0 then
			self.sound_loop_tmr = self.sound_loop_tmr - dtime
		elseif velocity==0 then
			if self.sound_loop_handle then
				minetest.sound_stop(self.sound_loop_handle)
				self.sound_loop_handle = nil
			end
			self.sound_loop_tmr=0
		end
	end,
	custom_on_step = function(self, dtime, data, train)
		--set line number
		local line = nil
		if train.line and self.line_cache ~= train.line then
			self.line_cache=train.line
			local lint = train.line
			if string.sub(train.line, 1, 1) == "S" then
				lint = string.sub(train.line,2)
			end
			if string.len(lint) == 1 then
				if lint=="X" then line="X" end
				line = tonumber(lint)
			elseif string.len(lint) == 2 then
				if tonumber(lint) then
					line = lint
				end
			end
			if line then
				local new_line_tex="advtrains_subway_wagon.png"
				if type(line)=="number" or line == "X" then
					new_line_tex = new_line_tex.."^advtrains_subway_wagon_line"..line..".png"
				else
					local num = tonumber(line)
					local red = math.fmod(line*67+101, 255)
					local green = math.fmod(line*97+109, 255)
					local blue = math.fmod(line*73+127, 255)
					new_line_tex = new_line_tex..string.format("^(advtrains_subway_wagon_line.png^[colorize:#%X%X%X%X%X%X)^(advtrains_subway_wagon_line%s_.png^advtrains_subway_wagon_line_%s.png", math.floor(red/16), math.fmod(red,16), math.floor(green/16), math.fmod(green,16), math.floor(blue/16), math.fmod(blue,16), string.sub(line, 1, 1), string.sub(line, 2, 2))
					if red + green + blue > 512 then
						new_line_tex = new_line_tex .. "^[colorize:#000)"
					else
						new_line_tex = new_line_tex .. ")"
					end
				end
				self.object:set_properties({
						textures={new_line_tex},
				})
			elseif self.line_cache~=nil and line==nil then
				self.object:set_properties({
						textures=self.textures,
				})
				self.line_cache=nil
			end
		end	
	end,
}, S("Subway Passenger Wagon"), "advtrains_subway_wagon_inv.png")

--wagons
minetest.register_craft({
	output = 'advtrains:subway_wagon',
	recipe = {
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
		{'default:steelblock', 'dye:yellow', 'default:steelblock'},
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
	},
})
