advtrains.outfitters = {}

local function show_outfitter_form(pos, player)
	local pe = advtrains.encode_pos(pos)
	local pname = player:get_player_name()
	if minetest.is_protected(pos, pname) then
		minetest.chat_send_player(pname, "Position is protected!")
		return
	end

	-- Load config data on this outfitter rail
	local stdata = advtrains.outfitters[pe]
	if not stdata then
		advtrains.outfitters[pe] = {}
		stdata = advtrains.outfitters[pe]
	end

	local wagontype_nice = "Mock wagon"
	local wagontype = "advtrains:subway_wagon"
	local texture_options = {
		{name="Interior", options={"woodgrain", "plastic"}},
		{name="Seat covers", options={"GVB", "Transib"}},
	}
	local sel_tex = {1,2}
	local colour_options = {
		{name="Exterior", options={"yellow", "red", "green", "blue", "#c00000"}},
		{name="Seat posts", options={"yellow", "green"}},
	}

	local form = "formspec_version[3]size[8,11]"
	form = form .. "label[0.5,0.5;"..attrans("Customising livery for: @1", wagontype_nice).."]"
	form = form .. "item_image[6,0.5;0.5,0.5;"..wagontype.."]"
	form = form .. "label[0.5,1.5;"..attrans("Texture options").."]"
	local y = 2
	for k,v in ipairs(texture_options) do
		form = form.."label[0.5,"..tostring(y)..";"..v.name.."]"
		form = form.."dropdown[2.5,"..tostring(y)..";3,0.5;texopt"..k..";"
		local numopts = #v.options
		for optidx, opt in ipairs(v.options) do
			form = form .. opt
			if optidx ~= numopts then
				form = form .. ","
			end
		end
		form = form..";"..sel_tex[k] .. "]"
		y = y + 1
	end
	
	form = form .. "label[0.5,"..y..";"..attrans("Colour options").."]"
	y = y +1
	for k,v in ipairs(colour_options) do
		form = form.."label[0.5,"..tostring(y)..";"..v.name.."]"
		local numopts = #v.options
		for optidx, opt in ipairs(v.options) do
			form = form.."image_button["..tostring((optidx*0.6))..","..tostring(y+0.2)..";0.5,0.5;"
				.. minetest.formspec_escape("unknown_item.png^[colorize:"..opt..":255")
				..";clrpreset"..k..","..optidx..";"..opt..";false;true]"
		end
		y = y + 1
	end
	
	form = form.."button[0.5,10;3.5,1;apply;"..attrans("Save").."]"
	form = form.."button[4,10;3.5,1;save;"..attrans("Apply").."]"
	
	minetest.chat_send_player(player:get_player_name(), form)
	
	minetest.show_formspec(pname, "at_lines_stop_"..pe, form)
end

local adefunc = function(def, preset, suffix, rotation)
	return {
		after_place_node=function(pos)
		end,
		after_dig_node=function(pos)
		end,
		on_rightclick = function(pos, node, player)
			show_outfitter_form(pos, player)
		end,
		advtrains = {
			on_train_approach = function(pos,train_id, train, index)
			end,
			on_train_enter = function(pos, train_id, train, index)
				--[[if train.path_cn[index] == 1 then
					local pe = advtrains.encode_pos(pos)
					local stdata = advtrains.lines.stops[pe]
					if not stdata then
						return
					end
					
					if stdata.ars and (stdata.ars.default or advtrains.interlocking.ars_check_rule_match(stdata.ars, train) ) then
						local stn = advtrains.lines.stations[stdata.stn]
						local stnname = stn and stn.name or "Unknown Station"
						
						-- Send ATC command and set text
						advtrains.atc.train_set_command(train, "B0 W O"..stdata.doors.." D"..stdata.wait.." OC "..(stdata.reverse and "R" or "").."D"..(stdata.ddelay or 1) .. "S" ..(stdata.speed or "M"), true)
						train.text_inside = stnname
						if tonumber(stdata.wait) then
							minetest.after(tonumber(stdata.wait), function() train.text_inside = "" end)
						end
					end
				end--]]
			end
		},
	}
end

if minetest.get_modpath("advtrains_train_track") ~= nil then
	advtrains.register_tracks("default", {
		nodename_prefix="advtrains_livery:dtrack_outfitter",
		texture_prefix="advtrains_dtrack_outfitter",
		models_prefix="advtrains_dtrack",
		models_suffix=".b3d",
		shared_texture="advtrains_dtrack_shared_outfitter.png",
		description="Outfitter Rail",
		formats={},
		get_additional_definiton = adefunc,
	}, advtrains.trackpresets.t_30deg_straightonly)
end