-- stoprail.lua
-- adds "stop rail". Recognized by lzb. (part of behavior is implemented there)


local adefunc = function(def, preset, suffix, rotation)
		return {
			after_place_node=function(pos)
				
			end,
			after_dig_node=function(pos)
				
			end,
			on_receive_fields = function(pos, formname, fields, player)
				
			end,
			advtrains = {
				on_train_enter = function(pos, train_id)
					local train = advtrains.trains[train_id]
					--advtrains.atc.train_set_command(train, "B0 OR D8 OC D1", true)
				end,
				on_train_approach = function(pos,train_id, train, index)
					advtrains.interlocking.lzb_add_oncoming_npr(train, index, 2)
				end,
			},
		}
end



advtrains.register_tracks("default", {
	nodename_prefix="advtrains_line_automation:dtrack_stop",
	texture_prefix="advtrains_dtrack_stop",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared_stop.png",
	description="Station/Stop Rail",
	formats={},
	get_additional_definiton = adefunc,
}, advtrains.trackpresets.t_30deg_straightonly)
