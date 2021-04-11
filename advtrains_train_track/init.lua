-- Default tracks for advtrains
-- (c) orwell96 and contributors

--flat
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack",
	texture_prefix="advtrains_dtrack",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared.png",
	description=attrans("Track"),
	formats={},
}, advtrains.ap.t_30deg_flat)

minetest.register_craft({
	output = 'advtrains:dtrack_placer 50',
	recipe = {
		{'default:steel_ingot', 'group:stick', 'default:steel_ingot'},
		{'default:steel_ingot', 'group:stick', 'default:steel_ingot'},
		{'default:steel_ingot', 'group:stick', 'default:steel_ingot'},
	},
})

-- y-turnout
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_sy",
	texture_prefix="advtrains_dtrack_sy",
	models_prefix="advtrains_dtrack_sy",
	models_suffix=".obj",
	shared_texture="advtrains_dtrack_shared.png",
	description=attrans("Y-turnout"),
	formats = {},
}, advtrains.ap.t_yturnout)
minetest.register_craft({
	output = 'advtrains:dtrack_sy_placer 2',
	recipe = {
		{'advtrains:dtrack_placer', '', 'advtrains:dtrack_placer'},
		{'', 'advtrains:dtrack_placer', ''},
		{'', 'advtrains:dtrack_placer', ''},
	},
})
--3-way turnout
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_s3",
	texture_prefix="advtrains_dtrack_s3",
	models_prefix="advtrains_dtrack_s3",
	models_suffix=".obj",
	shared_texture="advtrains_dtrack_shared.png",
	description=attrans("3-way turnout"),
	formats = {},
}, advtrains.ap.t_s3way)
minetest.register_craft({
	output = 'advtrains:dtrack_s3_placer 1',
	recipe = {
		{'advtrains:dtrack_placer', 'advtrains:dtrack_placer', 'advtrains:dtrack_placer'},
		{'', 'advtrains:dtrack_placer', ''},
		{'', '', ''},
	},
})

-- Diamond Crossings
-- perpendicular
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_xing",
	texture_prefix="advtrains_dtrack_xing",
	models_prefix="advtrains_dtrack_xing",
	models_suffix=".obj",
	shared_texture="advtrains_dtrack_shared.png",
	description=attrans("Perpendicular Diamond Crossing Track"),
	formats = {}
}, advtrains.ap.t_perpcrossing)

minetest.register_craft({
	output = 'advtrains:dtrack_xing_placer 3',
	recipe = {
		{'', 'advtrains:dtrack_placer', ''},
		{'advtrains:dtrack_placer', 'advtrains:dtrack_placer', 'advtrains:dtrack_placer'},
		{'', 'advtrains:dtrack_placer', ''}
	}
})

-- 90plusx
-- When you face east and param2=0, then this set of rails has a rail at 90
-- degrees to the viewer, plus another rail crossing at 30, 45 or 60 degrees.
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_xing90plusx",
	texture_prefix="advtrains_dtrack_xing4590",
	models_prefix="advtrains_dtrack_xing90plusx",
	models_suffix=".obj",
	shared_texture="advtrains_dtrack_shared.png",
	description=attrans("90+Angle Diamond Crossing Track"),
	formats = {}
}, advtrains.ap.t_90plusx_crossing)
minetest.register_craft({
	output = 'advtrains:dtrack_xing90plusx_placer 2',
	recipe = {
		{'advtrains:dtrack_placer', '', ''},
		{'advtrains:dtrack_placer', 'advtrains:dtrack_placer', 'advtrains:dtrack_placer'},
		{'', '', 'advtrains:dtrack_placer'}
	}
})
-- Deprecate any rails using the old name scheme
minetest.register_lbm({
	label = "Upgrade legacy 4590 rails",
	name = "advtrains_train_track:replace_legacy_4590",
	nodenames = {"advtrains:dtrack_xing4590_st"},
	run_at_every_load = true,
	action = function(pos, node)
		minetest.log("actionPos!: " .. pos.x .. "," .. pos.y .. "," .. pos.z)
		minetest.log("node!: " .. node.name .. "," .. node.param1 .. "," .. node.param2)
		advtrains.ndb.swap_node(pos,
		{
			name="advtrains:dtrack_xing90plusx_45l",
			param1=node.param1,
			param2=node.param2,
		})
	end
})
-- This will replace any items left in the inventory
minetest.register_alias("advtrains:dtrack_xing4590_placer", "advtrains:dtrack_xing90plusx_placer")

-- Diagonal
-- This set of rail crossings is named based on the angle of each intersecting
-- direction when facing east and param2=0. Rails with l/r swapped are mirror
-- images. For example, 30r45l is the mirror image of 30l45r.
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_xingdiag",
	texture_prefix="advtrains_dtrack_xingdiag",
	models_prefix="advtrains_dtrack_xingdiag",
	models_suffix=".obj",
	shared_texture="advtrains_dtrack_shared.png",
	description=attrans("Diagonal Diamond Crossing Track"),
	formats = {},
}, advtrains.ap.t_diagonalcrossing)
minetest.register_craft({
	output = 'advtrains:dtrack_xingdiag_placer 2',
	recipe = {
		{'advtrains:dtrack_placer', '', 'advtrains:dtrack_placer'},
		{'', 'advtrains:dtrack_placer', ''},
		{'advtrains:dtrack_placer', '', 'advtrains:dtrack_placer'}
	}
})
---- Not included: very shallow crossings like (30/60)+45.
---- At an angle of only 18.4 degrees, the models would not
---- translate well to a block game.
-- END crossings

--slopes
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack",
	texture_prefix="advtrains_dtrack",
	models_prefix="advtrains_dtrack",
	models_suffix=".obj",
	shared_texture="advtrains_dtrack_shared.png",
	second_texture="default_gravel.png",
	description=attrans("Track"),
	formats={vst1={true, false, true}, vst2={true, false, true}, vst31={true}, vst32={true}, vst33={true}},
}, advtrains.ap.t_30deg_slope)

minetest.register_craft({
	type = "shapeless",
	output = 'advtrains:dtrack_slopeplacer 2',
	recipe = {
		"advtrains:dtrack_placer",
		"advtrains:dtrack_placer",
		"default:gravel",
	},
})


--bumpers
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_bumper",
	texture_prefix="advtrains_dtrack_bumper",
	models_prefix="advtrains_dtrack_bumper",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_rail.png",
	--bumpers still use the old texture until the models are redone.
	description=attrans("Bumper"),
	formats={},
}, advtrains.ap.t_30deg_straightonly)
minetest.register_craft({
	output = 'advtrains:dtrack_bumper_placer 2',
	recipe = {
		{'group:wood', 'dye:red'},
		{'default:steel_ingot', 'default:steel_ingot'},
		{'advtrains:dtrack_placer', 'advtrains:dtrack_placer'},
	},
})
--legacy bumpers
for _,rot in ipairs({"", "_30", "_45", "_60"}) do
	minetest.register_alias("advtrains:dtrack_bumper"..rot, "advtrains:dtrack_bumper_st"..rot)
end
-- atc track
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_atc",
	texture_prefix="advtrains_dtrack_atc",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared_atc.png",
	description=attrans("ATC controller"),
	formats={},
	get_additional_definiton = advtrains.atc_function
}, advtrains.trackpresets.t_30deg_straightonly)


-- Tracks for loading and unloading trains
-- Copyright (C) 2017 Gabriel Pérez-Cerezo <gabriel@gpcf.eu>

local function get_far_node(pos)
	local node = minetest.get_node(pos)
	if node.name == "ignore" then
		minetest.get_voxel_manip():read_from_map(pos, pos)
		node = minetest.get_node(pos)
	end
	return node
end

local function train_load(pos, train_id, unload)
   local train=advtrains.trains[train_id]
   local below = get_far_node({x=pos.x, y=pos.y-1, z=pos.z})
   if not string.match(below.name, "chest") then
      atprint("this is not a chest! at "..minetest.pos_to_string(pos))
      return
   end
   local inv = minetest.get_inventory({type="node", pos={x=pos.x, y=pos.y-1, z=pos.z}})
   if inv and train.velocity < 2 then
      for k, v in ipairs(train.trainparts) do
			
			local i=minetest.get_inventory({type="detached", name="advtrains_wgn_"..v})
			if i and i:get_list("box") then
				if not unload then
					for _, item in ipairs(inv:get_list("main")) do
						if i:get_list("box") and i:room_for_item("box", item)  then
							i:add_item("box", item)
							inv:remove_item("main", item)
						end
					end
				else
					for _, item in ipairs(i:get_list("box")) do
						if inv:get_list("main") and inv:room_for_item("main", item)  then
							i:remove_item("box", item)
							inv:add_item("main", item)
						end
					end
				end
			end
      end
   end
end
			 



advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_unload",
	texture_prefix="advtrains_dtrack_unload",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared_unload.png",
	description=attrans("Unloading Track"),
	formats={},
	get_additional_definiton = function(def, preset, suffix, rotation)
		return {
		   after_dig_node=function(pos)
		      advtrains.invalidate_all_paths()
		      advtrains.ndb.clear(pos)
		   end,
		   advtrains = {
		      on_train_enter = function(pos, train_id)
			 train_load(pos, train_id, true)
		      end,
		   },
		}
	end
				     }, advtrains.trackpresets.t_30deg_straightonly)
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_load",
	texture_prefix="advtrains_dtrack_load",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared_load.png",
	description=attrans("Loading Track"),
	formats={},
	get_additional_definiton = function(def, preset, suffix, rotation)
		return {
		   after_dig_node=function(pos)
		      advtrains.invalidate_all_paths()
		      advtrains.ndb.clear(pos)
		   end,

		   advtrains = {
		      on_train_enter = function(pos, train_id)
			 train_load(pos, train_id, false)
		      end,
		   },
		}
	end
				     }, advtrains.trackpresets.t_30deg_straightonly)

-- mod-dependent crafts
local loader_core = "default:mese_crystal"  --fallback
if minetest.get_modpath("basic_materials") then
	loader_core = "basic_materials:ic"
elseif minetest.get_modpath("technic") then
	loader_core = "technic:control_logic_unit"
end
--print("Loader Core: "..loader_core)

minetest.register_craft({
	type="shapeless",
	output = 'advtrains:dtrack_load_placer',
	recipe = {
		"advtrains:dtrack_placer",
		loader_core,
		"default:chest"
	},
})
loader_core = nil --nil the crafting variable

--craft between load/unload tracks
minetest.register_craft({
	type="shapeless",
	output = 'advtrains:dtrack_unload_placer',
	recipe = {
		"advtrains:dtrack_load_placer",
	},
})
minetest.register_craft({
	type="shapeless",
	output = 'advtrains:dtrack_load_placer',
	recipe = {
		"advtrains:dtrack_unload_placer",
	},
})


if mesecon then
	advtrains.register_tracks("default", {
		nodename_prefix="advtrains:dtrack_detector_off",
		texture_prefix="advtrains_dtrack_detector",
		models_prefix="advtrains_dtrack",
		models_suffix=".b3d",
		shared_texture="advtrains_dtrack_shared_detector_off.png",
		description=attrans("Detector Rail"),
		formats={},
		get_additional_definiton = function(def, preset, suffix, rotation)
			return {
				mesecons = {
					receptor = {
						state = mesecon.state.off,
						rules = advtrains.meseconrules
					}
				},
				advtrains = {
					on_updated_from_nodedb = function(pos, node)
						mesecon.receptor_off(pos, advtrains.meseconrules)
					end,
					on_train_enter=function(pos, train_id)
						advtrains.ndb.swap_node(pos, {name="advtrains:dtrack_detector_on".."_"..suffix..rotation, param2=advtrains.ndb.get_node(pos).param2})
						if advtrains.is_node_loaded(pos) then
							mesecon.receptor_on(pos, advtrains.meseconrules)
						end
					end
				}
			}
		end
	}, advtrains.ap.t_30deg_straightonly)
	advtrains.register_tracks("default", {
		nodename_prefix="advtrains:dtrack_detector_on",
		texture_prefix="advtrains_dtrack",
		models_prefix="advtrains_dtrack",
		models_suffix=".b3d",
		shared_texture="advtrains_dtrack_shared_detector_on.png",
		description="Detector(on)(you hacker you)",
		formats={},
		get_additional_definiton = function(def, preset, suffix, rotation)
			return {
				mesecons = {
					receptor = {
						state = mesecon.state.on,
						rules = advtrains.meseconrules
					}
				},
				advtrains = {
					on_updated_from_nodedb = function(pos, node)
						mesecon.receptor_on(pos, advtrains.meseconrules)
					end,
					on_train_leave=function(pos, train_id)
						advtrains.ndb.swap_node(pos, {name="advtrains:dtrack_detector_off".."_"..suffix..rotation, param2=advtrains.ndb.get_node(pos).param2})
						if advtrains.is_node_loaded(pos) then
							mesecon.receptor_off(pos, advtrains.meseconrules)
						end
					end
				}
			}
		end
	}, advtrains.ap.t_30deg_straightonly_noplacer)
minetest.register_craft({
	type="shapeless",
	output = 'advtrains:dtrack_detector_off_placer',
	recipe = {
		"advtrains:dtrack_placer",
		"mesecons:wire_00000000_off"
	},
})
end
--TODO legacy
--I know lbms are better for this purpose
for name,rep in pairs({swl_st="swlst", swr_st="swrst", swl_cr="swlcr", swr_cr="swrcr", }) do
	minetest.register_abm({
    --  In the following two fields, also group:groupname will work.
        nodenames = {"advtrains:track_"..name},
       interval = 1.0, -- Operation interval in seconds
       chance = 1, -- Chance of trigger per-node per-interval is 1.0 / this
       action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:track_"..rep, param2=node.param2}) end,
    })
    minetest.register_abm({
    --  In the following two fields, also group:groupname will work.
        nodenames = {"advtrains:track_"..name.."_45"},
       interval = 1.0, -- Operation interval in seconds
       chance = 1, -- Chance of trigger per-node per-interval is 1.0 / this
       action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:track_"..rep.."_45", param2=node.param2}) end,
    })
end

if advtrains.register_replacement_lbms then
minetest.register_lbm({
	name = "advtrains:ramp_replacement_1",
--  In the following two fields, also group:groupname will work.
	nodenames = {"advtrains:track_vert1"},
	action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_vst1", param2=(node.param2+2)%4}) end,
})
minetest.register_lbm({
	name = "advtrains:ramp_replacement_1",
--  --  In the following two fields, also group:groupname will work.
	nodenames = {"advtrains:track_vert2"},
	action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_vst2", param2=(node.param2+2)%4}) end,
})
	minetest.register_abm({
		name = "advtrains:st_rep_1",
	--  In the following two fields, also group:groupname will work.
		nodenames = {"advtrains:track_st"},
		interval=1,
		chance=1,
		action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_st", param2=node.param2}) end,
	})
	minetest.register_lbm({
		name = "advtrains:st_rep_1",
	--  --  In the following two fields, also group:groupname will work.
		nodenames = {"advtrains:track_st_45"},
		action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_st_45", param2=node.param2}) end,
	})
end
