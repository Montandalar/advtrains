local S
if minetest.get_modpath("intllib") then
    S = intllib.Getter()
else
    S = function(s,a,...)a={a,...}return s:gsub("@(%d+)",function(n)return a[tonumber(n)]end)end
end

advtrains.register_wagon("subway_wagon", {
	mesh="advtrains_subway_wagon.b3d",
	textures = {"advtrains_subway_wagon.png"},
	drives_on={default=true},
	max_speed=15,
	seats = {
		{
			name="Driver stand",
			attach_offset={x=0, y=10, z=0},
			view_offset={x=0, y=0, z=0},
			group="dstand",
		},
		{
			name="1",
			attach_offset={x=-4, y=8, z=8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="2",
			attach_offset={x=4, y=8, z=8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="3",
			attach_offset={x=-4, y=8, z=-8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="4",
			attach_offset={x=4, y=8, z=-8},
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
	glow = -1, --supposed to disable effect of light to texture color, so that the entity always appears as full-bright
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
		if train.line then
			local lint = string.sub(train.line, 1, 1)
			line = tonumber(lint)
			if lint=="X" then line="X" end
		end
		if line and line~=self.line_cache then
			local new_line_tex="advtrains_subway_wagon.png^advtrains_subway_wagon_line"..line..".png"
			self.object:set_properties({
				textures={new_line_tex},
		 	})
			self.line_cache=line
		elseif self.line_cache~=nil and line==nil then
			self.object:set_properties({
				textures=self.textures,
		 	})
			self.line_cache=nil
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

minetest.register_craftitem(":advtrains:subway_train", {
		description = "Subway train, will drive forward when placed",
		inventory_image = "advtrains_subway_wagon_inv.png",
		wield_image = "advtrains_subway_wagon_inv.png",
		
		on_place = function(itemstack, placer, pointed_thing)
			return advtrains.pcall(function()
				if not pointed_thing.type == "node" then
					return
				end
				local pname = placer:get_player_name()

				local node=minetest.get_node_or_nil(pointed_thing.under)
				if not node then atprint("[advtrains]Ignore at placer position") return itemstack end
				local nodename=node.name
				if(not advtrains.is_track_and_drives_on(nodename, {default=true})) then
					atprint("no track here, not placing.")
					return itemstack
				end
				if not minetest.check_player_privs(placer, {train_operator = true }) then
					minetest.chat_send_player(pname, "You don't have the train_operator privilege.")
					return itemstack
				end
				if not minetest.check_player_privs(placer, {train_admin = true }) and minetest.is_protected(pointed_thing.under, placer:get_player_name()) then
					return itemstack
				end
				local tconns=advtrains.get_track_connections(node.name, node.param2)
				local yaw = placer:get_look_horizontal()
				local plconnid = advtrains.yawToClosestConn(yaw, tconns)
				
				local prevpos = advtrains.get_adjacent_rail(pointed_thing.under, tconns, plconnid, {default=true})
				if not prevpos then
					minetest.chat_send_player(pname, "The track you are trying to place the wagon on is not long enough!")
					return
				end
				
				local wid1 = advtrains.create_wagon("advtrains:subway_wagon", pname)
				local wid2 = advtrains.create_wagon("advtrains:subway_wagon", pname)
				local wid3 = advtrains.create_wagon("advtrains:subway_wagon", pname)
				
				local id=advtrains.create_new_train_at(pointed_thing.under, plconnid, 0, {wid1, wid2, wid3})
				
				minetest.after(2, function() advtrains.trains[id].tarvelocity = 2 end)
				
				if not advtrains.is_creative(pname) then
					itemstack:take_item()
				end
				return itemstack
				
			end)
		end,
	})
