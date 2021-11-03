
--[[
Advanced Trains - Minetest Mod

Copyright (C) 2016-2020  Moritz Blei (orwell96) and contributors

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

]]

local lot = os.clock()
minetest.log("action", "[advtrains] Loading...")

-- There is no need to support 0.4.x anymore given that the compatitability with it is already broken by 1bb1d825f46af3562554c12fba35a31b9f7973ff
attrans = minetest.get_translator ("advtrains")

--advtrains
advtrains = {trains={}, player_to_train_mapping={}}

-- =======================Development/debugging settings=====================
-- DO NOT USE FOR NORMAL OPERATION
local DUMP_DEBUG_SAVE = false
-- dump the save files in human-readable format into advtrains_DUMP

local GENERATE_ATRICIFIAL_LAG = false
local HOW_MANY_LAG = 1.0
-- Simulate a higher server step interval, as it occurs when the server is on high load

advtrains.IGNORE_WORLD = false
-- Run advtrains without respecting the world map
-- - No world collision checks occur
-- - The NDB forcibly places all nodes stored in it into the world regardless of the world's content.
-- - Rails do not set the 'attached_node' group
-- This mode can be useful for debugging/testing a world without the map data available
-- In this case, choose 'singlenode' as mapgen

local NO_SAVE = false
-- Do not save any data to advtrains save files

-- ==========================================================================

-- Use a global slowdown factor to slow down train movements. Now a setting
advtrains.DTIME_LIMIT = tonumber(minetest.settings:get("advtrains_dtime_limit")) or 0.2
advtrains.SAVE_INTERVAL = tonumber(minetest.settings:get("advtrains_save_interval")) or 60

--Constant for maximum connection value/division of the circle
AT_CMAX = 16

-- get wagon loading range
advtrains.wagon_load_range = tonumber(minetest.settings:get("advtrains_wagon_load_range"))
if not advtrains.wagon_load_range then
	advtrains.wagon_load_range = tonumber(minetest.settings:get("active_block_range"))*16
end

--pcall
local no_action=false

local function reload_saves()
	atwarn("Restoring saved state in 1 second...")
	no_action=true
	advtrains.lock_path_inval = false
	--read last save state and continue, as if server was restarted
	for aoi, le in pairs(minetest.luaentities) do
		if le.is_wagon then
			le.object:remove()
		end
	end
	minetest.after(1, function()
		advtrains.load()
		atwarn("Reload successful!")
		advtrains.ndb.restore_all()
	end)
end

advtrains.modpath = minetest.get_modpath("advtrains")

--Advtrains dump (special treatment of pos and sigd)
function atdump(t, intend)
	local str
	if type(t)=="table" then
		if t.x and t.y and t.z then
			str=minetest.pos_to_string(t)
		elseif t.p and t.s then -- interlocking sigd
			str="S["..minetest.pos_to_string(t.p).."/"..t.s.."]"
		elseif advtrains.lines and t.s and t.m then -- RwT
			str=advtrains.lines.rwt.to_string(t)
		else
			str="{"
			local intd = (intend or "") .. "  "
			for k,v in pairs(t) do
				if type(k)~="string" or not string.match(k, "^path[_]?") then
					-- do not print anything path-related
					str = str .. "\n" .. intd .. atdump(k, intd) .. " = " ..atdump(v, intd)
				end
			end
			str = str .. "\n" .. (intend or "") .. "}"
		end
	elseif type(t)=="boolean" then
		if t then
			str="true"
		else
			str="false"
		end
	elseif type(t)=="function" then
		str="<function>"
	elseif type(t)=="userdata" then
		str="<userdata>"
	else
		str=""..t
	end
	return str
end

function advtrains.print_concat_table(a)
	local str=""
	local stra=""
	local t
	for i=1,20 do
		t=a[i]
		if t==nil then
			stra=stra.."nil "
		else
			str=str..stra
			stra=""
			str=str..atdump(t).." "
		end
	end
	return str
end

atprint=function() end
atlog=function(t, ...)
	local text=advtrains.print_concat_table({t, ...})
	minetest.log("action", "[advtrains]"..text)
end
atwarn=function(t, ...)
	local text=advtrains.print_concat_table({t, ...})
	minetest.log("warning", "[advtrains]"..text)
	minetest.chat_send_all("[advtrains] -!- "..text)
end
sid=function(id) if id then return string.sub(id, -6) end end


--ONLY use this function for temporary debugging. for consistent debug prints use atprint
atdebug=function(t, ...)
	local text=advtrains.print_concat_table({t, ...})
	minetest.log("action", "[advtrains]"..text)
	minetest.chat_send_all("[advtrains]"..text)
end

if minetest.settings:get_bool("advtrains_enable_debugging") then
	atprint=function(t, ...)
		local context=advtrains.atprint_context_tid or ""
		if not context then return end
		local text=advtrains.print_concat_table({t, ...})
		advtrains.drb_record(context, text)
		
		--atlog("@@",advtrains.atprint_context_tid,t,...)
	end
	dofile(advtrains.modpath.."/debugringbuffer.lua")
	
end

function assertt(var, typ)
	if type(var)~=typ then
		error("Assertion failed, variable has to be of type "..typ)
	end
end

dofile(advtrains.modpath.."/helpers.lua");
--dofile(advtrains.modpath.."/debugitems.lua");

advtrains.meseconrules = 
{{x=0,  y=0,  z=-1},
 {x=1,  y=0,  z=0},
 {x=-1, y=0,  z=0},
 {x=0,  y=0,  z=1},
 {x=1,  y=1,  z=0},
 {x=1,  y=-1, z=0},
 {x=-1, y=1,  z=0},
 {x=-1, y=-1, z=0},
 {x=0,  y=1,  z=1},
 {x=0,  y=-1, z=1},
 {x=0,  y=1,  z=-1},
 {x=0,  y=-1, z=-1},
 {x=0, y=-2, z=0}}

advtrains.fpath=minetest.get_worldpath().."/advtrains"

advtrains.speed = dofile(advtrains.modpath.."/speed.lua")

dofile(advtrains.modpath.."/path.lua")
dofile(advtrains.modpath.."/trainlogic.lua")
dofile(advtrains.modpath.."/trainhud.lua")
dofile(advtrains.modpath.."/trackplacer.lua")
dofile(advtrains.modpath.."/copytool.lua")
dofile(advtrains.modpath.."/tracks.lua")
dofile(advtrains.modpath.."/occupation.lua")
dofile(advtrains.modpath.."/atc.lua")
dofile(advtrains.modpath.."/wagons.lua")
dofile(advtrains.modpath.."/protection.lua")

dofile(advtrains.modpath.."/trackdb_legacy.lua")
dofile(advtrains.modpath.."/nodedb.lua")
dofile(advtrains.modpath.."/couple.lua")

dofile(advtrains.modpath.."/signals.lua")
dofile(advtrains.modpath.."/misc_nodes.lua")
dofile(advtrains.modpath.."/crafting.lua")
dofile(advtrains.modpath.."/craft_items.lua")

dofile(advtrains.modpath.."/log.lua")
dofile(advtrains.modpath.."/passive.lua")
if mesecon then
	dofile(advtrains.modpath.."/p_mesecon_iface.lua")
end


dofile(advtrains.modpath.."/lzb.lua")


--load/save

-- backup variables, used if someone should accidentally delete a sub-mod
-- As of version 4, only used once during migration from version 3 to 4
-- Since version 4, each of the mods stores a separate save file.
local MDS_interlocking, MDS_lines


advtrains.fpath=minetest.get_worldpath().."/advtrains"
dofile(advtrains.modpath.."/log.lua")
function advtrains.read_component(name)
	local path = advtrains.fpath.."_"..name
	minetest.log("action", "[advtrains] loading "..path)
	local file, err = io.open(path, "r")
	if not file then
		minetest.log("warning", " Failed to read advtrains save data from file "..path..": "..(err or "Unknown Error"))
		minetest.log("warning", " (this is normal when first enabling advtrains on this world)")
		return
	end
	local tbl =  minetest.deserialize(file:read("*a"))
	file:close()
	return tbl
end

function advtrains.avt_load()
	-- check for new, split advtrains save file
	
	local version = advtrains.read_component("version")
	local tbl
	if version and version == 4 then
		advtrains.load_version_4()
		return
	-- NOTE: From here, legacy loading code!
	elseif version and version == 3 then
		-- we are dealing with the split-up system
		minetest.log("action", "[advtrains] loading savefiles version 3")
		local il_save = {
			tcbs = true,
			ts = true,
			signalass = true,
			rs_locks = true,
			rs_callbacks = true,
			influence_points = true,
			npr_rails = true,
		}
		tbl={
			trains = true,
			wagon_save = true,
			ptmap = true,
			atc = true,
			ndb = true,		
			lines = true,
			version = 2,
		}
		for i,k in pairs(il_save) do
			il_save[i] = advtrains.read_component("interlocking_"..i)
		end
		for i,k in pairs(tbl) do
			tbl[i] = advtrains.read_component(i)
		end
		tbl["interlocking"] = il_save
	else	
		local file, err = io.open(advtrains.fpath, "r")
		if not file then
			minetest.log("warning", " Failed to read advtrains save data from file "..advtrains.fpath..": "..(err or "Unknown Error"))
			minetest.log("warning", " (this is normal when first enabling advtrains on this world)")
			return
		else
			tbl = minetest.deserialize(file:read("*a"))
			file:close()
		end
	end
	if type(tbl) == "table" then
		if tbl.version then
			--congrats, we have the new save format.
			advtrains.trains = tbl.trains
			--Save the train id into the train table to avoid having to pass id around
			for id, train in pairs(advtrains.trains) do
				train.id = id
			end
			advtrains.wagons = tbl.wagon_save
			advtrains.player_to_train_mapping = tbl.ptmap or {}
			advtrains.ndb.load_data_pre_v4(tbl.ndb)
			advtrains.atc.load_data(tbl.atc)
			if advtrains.interlocking then
				advtrains.interlocking.db.load(tbl.interlocking)
			else
				MDS_interlocking = tbl.interlocking
			end
			if advtrains.lines then
				advtrains.lines.load(tbl.lines)
			else
				MDS_lines = tbl.lines
			end
			--remove wagon_save entries that are not part of a train
			local todel=advtrains.merge_tables(advtrains.wagon_save)
			for tid, train in pairs(advtrains.trains) do
				train.id = tid
				for _, wid in ipairs(train.trainparts) do
					todel[wid]=nil
				end
			end
			for wid, _ in pairs(todel) do
				atwarn("Removing unused wagon", wid, "from wagon_save table.")
				advtrains.wagon_save[wid]=nil
			end
		else
			--oh no, its the old one...
			advtrains.trains=tbl
			--load ATC
			advtrains.fpath_atc=minetest.get_worldpath().."/advtrains_atc"
			local file, err = io.open(advtrains.fpath_atc, "r")
			if not file then
				local er=err or "Unknown Error"
				atprint("Failed loading advtrains atc save file "..er)
			else
				local tbl = minetest.deserialize(file:read("*a"))
				if type(tbl) == "table" then
					advtrains.atc.controllers=tbl.controllers
				end
				file:close()
			end
			--load wagon saves
			advtrains.fpath_ws=minetest.get_worldpath().."/advtrains_wagon_save"
			local file, err = io.open(advtrains.fpath_ws, "r")
			if not file then
				local er=err or "Unknown Error"
				atprint("Failed loading advtrains save file "..er)
			else
				local tbl = minetest.deserialize(file:read("*a"))
				if type(tbl) == "table" then
					advtrains.wagon_save=tbl
				end
				file:close()
			end
		end
	else
		minetest.log("error", " Failed to deserialize advtrains save data: Not a table!")
	end
	-- moved from advtrains.load()
	atlatc.load_pre_v4()
	-- end of legacy loading code
end

function advtrains.load_version_4()
	minetest.log("action", "[advtrains] loading savefiles version 4 (serialize_lib)")

	--== load core ==
	local at_save = serialize_lib.load_atomic(advtrains.fpath.."_core.ls")
	if at_save then
		advtrains.trains = at_save.trains
		--Save the train id into the train table to avoid having to pass id around
		for id, train in pairs(advtrains.trains) do
			train.id = id
		end
		advtrains.wagons = at_save.wagons
		advtrains.player_to_train_mapping = at_save.ptmap or {}
		advtrains.atc.load_data(at_save.atc)

		--remove wagon_save entries that are not part of a train
		local todel=advtrains.merge_tables(advtrains.wagon_save)
		for tid, train in pairs(advtrains.trains) do
			train.id = tid
			for _, wid in ipairs(train.trainparts) do
				todel[wid]=nil
			end
		end
		for wid, _ in pairs(todel) do
			atwarn("Removing unused wagon", wid, "from wagon_save table.")
			advtrains.wagon_save[wid]=nil
		end
	end
	--== load ndb
	serialize_lib.load_atomic(advtrains.fpath.."_ndb4.ls", advtrains.ndb.load_callback)
	
	--== load interlocking ==
	if advtrains.interlocking then
		local il_save = serialize_lib.load_atomic(advtrains.fpath.."_interlocking.ls")
		if il_save then
			advtrains.interlocking.db.load(il_save)
		end
	end
	
	--== load lines ==
	if advtrains.lines then
		local ln_save = serialize_lib.load_atomic(advtrains.fpath.."_lines.ls")
		if ln_save then
			advtrains.lines.load(ln_save)
		end
	end
	
	--== load luaatc ==
	if atlatc then
		local la_save = serialize_lib.load_atomic(advtrains.fpath.."_atlatc.ls")
		if la_save then
			atlatc.load(la_save)
		end
	end
end

advtrains.save_component = function (tbl, name)
	-- Saves each component of the advtrains file separately
	--
	-- required for now to shrink the advtrains db to overcome lua
	-- limitations.
	-- Note: as of version 4, only used for the "advtrains_version" file
	local datastr = minetest.serialize(tbl)
	if not datastr then
		minetest.log("error", " Failed to serialize advtrains save data!")
		return
	end
	local path = advtrains.fpath.."_"..name
	local success = minetest.safe_file_write(path, datastr)
	
	if not success then
		minetest.log("error", " Failed to write advtrains save data to file "..path)
	end
	
end

advtrains.avt_save = function(remove_players_from_wagons)
	--atdebug("Saving advtrains files (version 4)")
	
	if remove_players_from_wagons then
		for w_id, data in pairs(advtrains.wagons) do
			data.seatp={}
		end
		advtrains.player_to_train_mapping={}
	end
	
	local tmp_trains={}
	for id, train in pairs(advtrains.trains) do
		--first, deep_copy the train
		if #train.trainparts > 0 then
			local v=advtrains.save_keys(train, {
				"last_pos", "last_connid", "last_frac", "velocity", "tarvelocity",
				"trainparts", "recently_collided_with_env",
				"atc_brake_target", "atc_wait_finish", "atc_command", "atc_delay", "door_open",
				"text_outside", "text_inside", "line", "routingcode",
				"il_sections", "speed_restriction", "speed_restrictions_t", "is_shunt",
				"points_split", "autocouple", "atc_wait_autocouple", "ars_disable",
			})
			--then save it
			tmp_trains[id]=v
		else
			atwarn("Train",id,"had no wagons left because of some bug. It is being deleted. Wave it goodbye!")
			advtrains.remove_train(id)
		end
	end
	
	for id, wdata in pairs(advtrains.wagons) do
		local _,proto = advtrains.get_wagon_prototype(wdata)
		if proto.has_inventory then
			local inv=minetest.get_inventory({type="detached", name="advtrains_wgn_"..id})
			if inv then -- inventory is not initialized when wagon was never loaded
				-- TOOD: What happens with unloading rails when they don't find the inventory?
				wdata.ser_inv=advtrains.serialize_inventory(inv)
			end
		end
		-- TODO apply save-keys here too
		-- TODO temp
		wdata.dcpl_lock = nil
	end
	
	--versions:
	-- 1 - Initial new save format.
	-- 2 - version as of tss branch 11-2018+
	-- 3 - split-up savefile system by gabriel
	-- 4 - serialize_lib

	-- save of core advtrains
	local at_save={
		trains = tmp_trains,
		wagons = advtrains.wagons,
		ptmap = advtrains.player_to_train_mapping,
		atc = advtrains.atc.save_data(),
	}
	
	--save of interlocking
	local il_save
	if advtrains.interlocking then
		il_save = advtrains.interlocking.db.save()
	else
		il_save = MDS_interlocking
	end
	
	-- save of lines
	local ln_save
	if advtrains.lines then
		ln_save = advtrains.lines.save()
	else
		ln_save = MDS_lines
	end
	
	-- save of luaatc
	local la_save
	if atlatc then
		la_save = atlatc.save()
	end
	
	-- parts table for serialize_lib API:
	-- any table that is nil will not be included and thus not be overwritten
	local parts_table = {
		["core.ls"] = at_save,
		["interlocking.ls"] = il_save,
		["lines.ls"] = ln_save,
		["atlatc.ls"] = la_save,
		["ndb4.ls"] = true, -- data not used
	}
	local callbacks_table = {
		["ndb4.ls"] = advtrains.ndb.save_callback
	}
	
	if DUMP_DEBUG_SAVE then
		local file, err = io.open(advtrains.fpath.."_DUMP", "w")
		if err then
			return
		end
		file:write(dump(parts_table))
		file:close()
	end
	
	--THE MAGIC HAPPENS HERE
	local succ, err = serialize_lib.save_atomic_multiple(parts_table, advtrains.fpath.."_", callbacks_table)
	
	if not succ then
		atwarn("Saving failed: "..err)
	else
		-- store version
		advtrains.save_component(4, "version")
	end
end

--## MAIN LOOP ##--
--Calls all subsequent main tasks of both advtrains and atlatc
local init_load=false
local save_timer = advtrains.SAVE_INTERVAL
advtrains.mainloop_runcnt=0
advtrains.global_slowdown = 1

local t = 0
local within_mainstep = false
minetest.register_globalstep(function(dtime_mt)
		if no_action then
			-- the advtrains globalstep is skipped by command. Return immediately
			return
		end
		within_mainstep = true

		advtrains.mainloop_runcnt=advtrains.mainloop_runcnt+1
		--atprint("Running the main loop, runcnt",advtrains.mainloop_runcnt)
		--call load once. see advtrains.load() comment
		if not init_load then
			advtrains.load()
		end
		
		local dtime = dtime_mt * advtrains.global_slowdown
		if GENERATE_ATRICIFIAL_LAG then
			dtime = HOW_MANY_LAG
			if os.clock()<t then
				within_mainstep = false
				return
			end
			
			t = os.clock()+HOW_MANY_LAG
		end
		-- if dtime is too high, decrease global slowdown
		if advtrains.DTIME_LIMIT~=0 then
			if dtime > advtrains.DTIME_LIMIT then
				if advtrains.global_slowdown > 0.1 then
					advtrains.global_slowdown = advtrains.global_slowdown - 0.05
				else
					advtrains.global_slowdown = advtrains.global_slowdown / 2
				end
				dtime = advtrains.DTIME_LIMIT
			end
			-- recover global slowdown slowly over time
			advtrains.global_slowdown = math.min(advtrains.global_slowdown*1.02, 1)
		end
		
		advtrains.mainloop_trainlogic(dtime,advtrains.mainloop_runcnt)
		if advtrains_itm_mainloop then
			advtrains_itm_mainloop(dtime)
		end
		if atlatc then
			--atlatc.mainloop_stepcode(dtime)
			atlatc.interrupt.mainloop(dtime)
		end
		if advtrains.lines then
			advtrains.lines.step(dtime)
		end

		--trigger a save when necessary
		save_timer=save_timer-dtime
		if save_timer<=0 then
			local t=os.clock()
			--save
			advtrains.save()
			save_timer = advtrains.SAVE_INTERVAL
			atprintbm("saving", t)
		end

		within_mainstep = false

end)

--if something goes wrong in these functions, there is no help. no pcall here.

--## MAIN LOAD ROUTINE ##
-- Causes the loading of everything
-- first time called in main loop (after the init phase) because luaautomation has to initialize first.
function advtrains.load()
	advtrains.avt_load() --loading advtrains. includes ndb at advtrains.ndb.load_data()
	--if atlatc then
	--	atlatc.load() --includes interrupts
	--end == No longer loading here. Now part of avt_save() legacy loading.
	if advtrains_itm_init then
		advtrains_itm_init()
	end
	init_load=true
	no_action=false
	atlog("[load_all]Loaded advtrains save files")
end

--## MAIN SAVE ROUTINE ##
-- Causes the saving of everything
function advtrains.save(remove_players_from_wagons)
	if not init_load then
		--wait... we haven't loaded yet?!
		atwarn("Instructed to save() but load() was never called!")
		return
	end
	
	if advtrains.IGNORE_WORLD then
		advtrains.ndb.restore_all()
	end
	
	if NO_SAVE then
		return
	end
	if no_action then
		atlog("[save] Saving requested externally, but Advtrains step is disabled. Not saving any data as state may be inconsistent.")
		return
	end
	
	local t1 = os.clock()
	advtrains.avt_save(remove_players_from_wagons) --saving advtrains. includes ndb at advtrains.ndb.save_data()
	if atlatc then
		atlatc.save()
	end
	atlog("Saved advtrains save files, took",math.floor((os.clock()-t1) * 1000),"ms")
	
	-- Cleanup actions
	--TODO very simple yet hacky workaround for the "green signals" bug
	advtrains.invalidate_all_paths()
end
minetest.register_on_shutdown(function()
	if within_mainstep then
		atwarn("Crash during advtrains main step - skipping the shutdown save operation to not save inconsistent data!")
	else
		advtrains.save()
	end
end)

-- This chat command provides a solution to the problem known on the LinuxWorks server
-- There are many players that joined a single time, got on a train and then left forever
-- These players still occupy seats in the trains.
minetest.register_chatcommand("at_empty_seats",
	{
        params = "", -- Short parameter description
        description = "Detach all players, especially the offline ones, from all trains. Use only when no one serious is on a train.", -- Full description
        privs = {train_operator=true, server=true}, -- Require the "privs" privilege to run
        func = function(name, param)
				atwarn("Data is being saved. While saving, advtrains will remove the players from trains. Save files will be reloaded afterwards!")
				advtrains.save(true)
				reload_saves()
        end,
})
-- This chat command solves another problem: Trains getting randomly stuck.
minetest.register_chatcommand("at_reroute",
	{
        params = "", 
        description = "Delete all train routes, force them to recalculate", 
        privs = {train_operator=true}, -- Only train operator is required, since this is relatively safe.
        func = function(name, param)
				advtrains.invalidate_all_paths()
				return true, "Successfully invalidated train routes"
        end,
})

minetest.register_chatcommand("at_whereis",
	{
		params = "<train id>",
		description = "Returns the position of the train with the given id",
		privs = {train_operator = true},
		func = function(name,param)
			local train = advtrains.trains[param] 
			if not train or not train.last_pos then
				return false, "Train "..param.." does not exist or is invalid"
			else
				return true, "Train "..param.." is at "..minetest.pos_to_string(train.last_pos)
			end
		end,
})
minetest.register_chatcommand("at_disable_step",
	{
        params = "<yes/no>", 
        description = "Disable the advtrains globalstep temporarily", 
        privs = {server=true},
        func = function(name, param)
			if minetest.is_yes(param) then
				-- disable everything, and turn off saving
				no_action = true;
				atwarn("The advtrains globalstep has been disabled. Trains are not moving, and no data is saved! Run '/at_disable_step no' to enable again!")
				return true, "Disabled advtrains successfully"
			elseif no_action then
				atwarn("Re-enabling advtrains globalstep...")
				reload_saves()
				return true
			else
				return false, "Advtrains is already running normally!"
			end
        end,
})

advtrains.is_no_action = function()
	return no_action
end


local tot=(os.clock()-lot)*1000
minetest.log("action", "[advtrains] Loaded in "..tot.."ms")

