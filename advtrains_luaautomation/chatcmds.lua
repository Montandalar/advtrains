--chatcmds.lua
--Registers commands to modify the init and step code for LuaAutomation

local function get_init_form(env, pname)
	local err = env.init_err or ""
	local code = env.init_code or ""

	local form = "size["..atlatc.CODE_FORM_SIZE.."]"
		.."style[code;font=mono]"
		.."button[0.0,0.2;2.5,1;run;Run Init Code]"
		.."button[2.5,0.2;2.5,1;cls;Clear S]"
		.."button[5.0,0.2;2.5,1;save;Save]"
		.."button[7.5,0.2;2.5,1;del;Delete Env.]"
		.."textarea[0.3,1.5;"..atlatc.CODE_FORM_SIZE..";code;Environment initialization code;"..minetest.formspec_escape(code).."]"
		.."label[0.0,9.7;"..err.."]"
	return form
end

core.register_chatcommand("env_setup", {
	params = "<environment name>",
	description = "Set up and modify AdvTrains LuaAutomation environment",
	privs = {atlatc=true},
	func = function(name, param)
		local env=atlatc.envs[param]
		if not env then return false,"Invalid environment name!" end
		minetest.show_formspec(name, "atlatc_envsetup_"..param, get_init_form(env, name))
		return true
	end,
})

core.register_chatcommand("env_create", {
	params = "<environment name>",
	description = "Create an AdvTrains LuaAutomation environment",
	privs = {atlatc=true},
	func = function(name, param)
		if not param or param=="" then return false, "Name required!" end
		if string.find(param, "[^a-zA-Z0-9-_]") then return false, "Invalid name (only common characters)" end
		if atlatc.envs[param] then return false, "Environment already exists!" end
		atlatc.envs[param] = atlatc.env_new(param)
		atlatc.envs[param].subscribers = {name}
		return true, "Created environment '"..param.."'. Use '/env_setup "..param.."' to define global initialization code, or start building LuaATC components!"
	end,
})
core.register_chatcommand("env_subscribe", {
	params = "<environment name>",
	description = "Subscribe to the log of an Advtrains LuaATC environment",
	privs = {atlatc=true},
	func = function(name, param)
		local env=atlatc.envs[param]
		if not env then return false,"Invalid environment name!" end
		for _,pname in ipairs(env.subscribers) do
			if pname==name then
				return false, "Already subscribed!"
			end
		end
		table.insert(env.subscribers, name)
		return true, "Subscribed to environment '"..param.."'."
	end,
})
core.register_chatcommand("env_unsubscribe", {
	params = "<environment name>",
	description = "Unubscribe to the log of an Advtrains LuaATC environment",
	privs = {atlatc=true},
	func = function(name, param)
		local env=atlatc.envs[param]
		if not env then return false,"Invalid environment name!" end
		for index,pname in ipairs(env.subscribers) do
			if pname==name then
				table.remove(env.subscribers, index)
				return true, "Successfully unsubscribed!"
			end
		end
		return false, "Not subscribed to environment '"..param.."'."
	end,	
})
core.register_chatcommand("env_subscriptions", {
	params = "[environment name]",
	description = "List Advtrains LuaATC environments you are subscribed to (no parameters) or subscribers of an environment (giving an env name).",
	privs = {atlatc=true},
	func = function(name, param)
		if not param or param=="" then
			local none=true
			for envname, env in pairs(atlatc.envs) do
				for _,pname in ipairs(env.subscribers) do
					if pname==name then
						none=false
						minetest.chat_send_player(name, envname)
					end
				end
			end
			if none then
				return false, "Not subscribed to any!"
			end
			return true
		end
		local env=atlatc.envs[param]
		if not env then return false,"Invalid environment name!" end
		local none=true
		for index,pname in ipairs(env.subscribers) do
			none=false
			minetest.chat_send_player(name, pname)
		end
		if none then
			return false, "No subscribers!"
		end
		return true
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	
	local pname=player:get_player_name()
	if not minetest.check_player_privs(pname, {atlatc=true}) then return end
	
	local envname=string.match(formname, "^atlatc_delconfirm_(.+)$")
	if envname and fields.sure=="YES" then
		atlatc.envs[envname]=nil
		minetest.chat_send_player(pname, "Environment deleted!")
		return
	end
	
	envname=string.match(formname, "^atlatc_envsetup_(.+)$")
	if not envname then return end
	
	local env=atlatc.envs[envname]
	if not env then return end
	
	if fields.del then
		minetest.show_formspec(pname, "atlatc_delconfirm_"..envname, "field[sure;"..minetest.formspec_escape("SURE TO DELETE ENVIRONMENT "..envname.."? Type YES (all uppercase) to continue or just quit form to cancel.")..";]")
		return
	end
	
	env.init_err=nil
	if fields.code then
		env.init_code=fields.code
	end
	if fields.run then
		env:run_initcode()
		minetest.show_formspec(pname, formname, get_init_form(env, pname))
	end
end)
