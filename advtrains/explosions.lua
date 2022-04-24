minetest.register_entity("advtrains:explosion_fireball", {
	initial_properties = {
		visual = "sprite",
		visual_size = vector.new(4,4,4),
		textures = {"advtrains_vehicle_explosion.png"},
		fullbright = 1,
		spritediv = {x=1, y=15},
		initial_sprite_basepos = {x=0, y=0},
		collisionbox = {0,0,0,0,0,0},

		physical = false,
		collide_with_objects = false,
	},
	on_activate = function(self, staticdata, dtime_s)
		--print(dump(self.object))
		local so = self.object
		so:set_sprite({x=0, y=0}, 15, 0.08, false)
		so:set_armor_groups({fleshy=0, explody=1})

		local pos = so:get_pos()
		minetest.sound_play("explosion", {
			pos = pos,
			gain = 0.5,
			max_hear_distance = 16,
		})

		minetest.after( 1.1, so.punch, so, so,
			1, {full_punch_interval = 1.0, damage_groups = {explody = 1000} },
			nil
		)
	end
})
