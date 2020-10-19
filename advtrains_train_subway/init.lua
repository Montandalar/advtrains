local S = attrans

-- Gets called one, currently when punched with bike painter
local function subway_set_livery(self, puncher, itemstack,data)
	-- Get color data from the bike painter
	local meta = itemstack:get_meta()
	local color = meta:get_string("paint_color")
	local alpha = tonumber(meta:get_string("alpha"))
	if color and color:find("^#%x%x%x%x%x%x$") then
		if alpha == 0 then
			data.livery = "advtrains_subway_wagon.png"
		else 
			data.livery = "advtrains_subway_wagon.png^(advtrains_subway_wagon_livery.png^[colorize:"..color..":"..alpha..")^advtrains_subway_wagon_extoverlay.png" -- livery texture has no own texture....
		end
		self:set_textures(data)
	end
end

-- Gets called when an entity is made - will set the right livery that was painted
local function subway_set_textures(self, data)
	if data.livery then
		self.object:set_properties({
				textures={data.livery}
		})
	end
end

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
		if train.line and self.line_cache == train.line then
			return
		end

		local line = train.line
		self.line_cache = line

		if line == nil then
			return
		end
		if line:find("[SsUuEe]", 1) == 1 then
			line = line:sub(2)
		end
		local newtex = data.livery or "advtrains_subway_wagon.png"
		local int = tonumber(line)
		if int == nil then
			if line:find("[xX]") then
				-- X texture
				newtex = newtex .. "^advtrains_subway_wagon_lineX.png"
			else
				newtex = nil
			end
		else
			local strlen = #line
			if strlen == 1 then
				-- Texture 0-9
				newtex = string.format("%s^advtrains_subway_wagon_line%d.png", newtex, line)
			elseif strlen == 2 then
				-- Hume2's algorithm for 2 digits
				local num = tonumber(line)
				local red = math.fmod(line*67+101, 255)
				local green = math.fmod(line*97+109, 255)
				local blue = math.fmod(line*73+127, 255)
				newtex = string.format(
					"%s^(advtrains_subway_wagon_line.png^[colorize:#%X%X%X%X%X%X)^(advtrains_subway_wagon_line%s_.png^advtrains_subway_wagon_line_%s.png",
					newtex, math.floor(red/16), math.fmod(red,16), math.floor(green/16), math.fmod(green,16), math.floor(blue/16), math.fmod(blue,16),
					string.sub(line, 1, 1), string.sub(line, 2, 2)
				)
				if red + green + blue > 512 then
					newtex = newtex .. "^[colorize:#000"
				end
				newtex = newtex .. ")"
			else
				-- No texture
				newtex = nil
			end
		end
		
		if (newtex ~= nil) then
			self.object:set_properties({textures = {newtex}})
		end
	end,--[[ --]]
	set_textures = subway_set_textures,
	set_livery = subway_set_livery,
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
