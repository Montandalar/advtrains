-- atomic.lua
-- Utilities for transaction-like handling of serialized state files
-- Also for multiple files that must be synchronous, as advtrains currently requires.


-- Managing files and backups
-- ==========================

--[[
The plain scheme just overwrites the file in place. This however poses problems when we are interrupted right within
the write, so we have incomplete data. So, the following scheme is applied:
Unix:
1. writes to <filename>.new
2. moves <filename>.new to <filename>, clobbering previous file
Windows:
1. writes to <filename>.new
2. delete <filename>
3. moves <filename>.new to <filename>

We count a new version of the state as "committed" after stage 2.

During loading, we apply the following order of precedence:
1. <filename>
2. <filename>.new (windows only, in case we were interrupted just before 3. when saving)


All of these functions return either true on success or nil, error on error.
]]--

local ser = serialize_lib.serialize

local windows_mode = false

-- == local functions ==

local function save_atomic_move_file(filename)
	--2. if windows mode, delete main file
	if windows_mode then
		local delsucc, err = os.remove(filename)
		if not delsucc then
			serialize_lib.log_warn("Unable to delete old savefile '"..filename.."':")
			serialize_lib.log_warn(err)
			serialize_lib.log_info("Trying to replace the save file anyway now...")
		end
	end
	
	--3. move file
	local mvsucc, err = os.rename(filename..".new", filename)
	if not mvsucc then
		if minetest.settings:get_bool("serialize_lib_no_auto_windows_mode") or windows_mode then
			serialize_lib.log_error("Unable to replace save file '"..filename.."':")
			serialize_lib.log_error(err)
			return nil, err
		else
			-- enable windows mode and try again
			serialize_lib.log_info("Unable to replace save file '"..filename.."' by direct renaming:")
			serialize_lib.log_info(err)
			serialize_lib.log_info("Enabling Windows mode for atomic saving...")
			windows_mode = true
			return save_atomic_move_file(filename)
		end
	end
	
	return true
end

local function open_file_and_save_callback(callback, filename)
	local file, err = io.open(filename, "wb")
	if not file then
		error("Failed opening file '"..filename.."' for write:\n"..err)
	end
	
	callback(file)
	return true
end

local function open_file_and_load_callback(filename, callback)
	local file, err = io.open(filename, "rb")
	if not file then
		error("Failed opening file '"..filename.."' for read:\n"..err)
	end
	
	return callback(file)
end

-- == public functions ==

-- Load a saved state (according to comment above)
-- if 'callback' is nil: reads serialized table.
-- returns the read table, or nil,err on error
-- if 'callback' is a function (signature func(file_handle) ):
-- Counterpart to save_atomic with function argument. Opens the file and calls callback on it.
-- If the callback function throws an error, and strict loading is enabled, that error is propagated.
-- The callback's first return value is returned by load_atomic
function serialize_lib.load_atomic(filename, callback)
	
	local cbfunc = callback or ser.read_from_fd
	
	-- try <filename>
	local file, ret = io.open(filename, "rb")
	if file then
		-- read the file using the callback
		local success
		success, ret = pcall(cbfunc, file)
		if success then
			return ret
		end
	end
	
	if minetest.settings:get_bool("serialize_lib_strict_loading", true) then
		serialize_lib.save_lock = true
		error("Loading data from file '"..filename.."' failed:\n"
				..ret.."\nDisable Strict Loading to ignore.")
	end
		
	serialize_lib.log_warn("Loading data from file '"..filename.."' failed, trying .new fallback:")
	serialize_lib.log_warn(ret)
	
	-- try <filename>.new
	file, ret = io.open(filename..".new", "rb")
	if file then
		-- read the file using the callback
		local success
		success, ret = pcall(cbfunc, file)
		if success then
			return ret
		end
	end
	
	serialize_lib.log_error("Unable to load data from '"..filename..".new':")
	serialize_lib.log_error(ret)
	serialize_lib.log_error("Note: This message is normal when the mod is loaded the first time on this world.")
	
	return nil, ret
end

-- Save a file atomically (as described above)
-- 'data' is the data to be saved (when a callback is used, this can be nil)
-- if 'callback' is nil:
-- data must be a table, and is serialized into the file
-- if 'callback' is a function (signature func(data, file_handle) ):
-- Opens the file and calls callback on it. The 'data' argument is the data passed to save_atomic().
-- If the callback function throws an error, and strict loading is enabled, that error is propagated.
-- The callback's first return value is returned by load_atomic
-- Important: the callback must close the file in all cases!
function serialize_lib.save_atomic(data, filename, callback, config)
	if serialize_lib.save_lock then
		serialize_lib.log_warn("Instructed to save '"..filename.."', but save lock is active!")
		return nil
	end
	
	local cbfunc = callback or ser.write_to_fd

	local file, ret = io.open(filename..".new", "wb")
	if file then
		-- save the file using the callback
		local success
		success, ret = pcall(cbfunc, data, file)
		if success then
			return save_atomic_move_file(filename)
		end
	end
	serialize_lib.log_error("Unable to save data to '"..filename..".new':")
	serialize_lib.log_error(ret)
	return nil, ret
end


-- Saves multiple files synchronously. First writes all data to all <filename>.new files,
-- then moves all files in quick succession to avoid inconsistent backups.
-- parts_table is a table where the keys are used as part of the filename and the values
-- are the respective data written to it.
-- e.g. if parts_table={foo={...}, bar={...}}, then <filename_prefix>foo and <filename_prefix>bar are written out.
-- if 'callbacks_table' is defined, it is consulted for callbacks the same way save_atomic does.
-- example: if callbacks_table = {foo = func()...}, then the callback is used during writing of file 'foo' (but not for 'bar')
-- Note however that you must at least insert a "true" in the parts_table if you don't use the data argument.
-- Important: the callback must close the file in all cases!
function serialize_lib.save_atomic_multiple(parts_table, filename_prefix, callbacks_table, config)
	if serialize_lib.save_lock then
		serialize_lib.log_warn("Instructed to save '"..filename_prefix.."' (multiple), but save lock is active!")
		return nil
	end
	
	for subfile, data in pairs(parts_table) do
		local filename = filename_prefix..subfile
		local cbfunc = ser.write_to_fd
		if callbacks_table and callbacks_table[subfile] then
			cbfunc = callbacks_table[subfile]
		end
		
		local success = false
		local file, ret = io.open(filename..".new", "wb")
		if file then
			-- save the file using the callback
			success, ret = pcall(cbfunc, data, file, config)
		end
		
		if not success then
			serialize_lib.log_error("Unable to save data to '"..filename..".new':")
			serialize_lib.log_error(ret)
			return nil, ret
		end
	end
	
	local first_error
	for file, _ in pairs(parts_table) do
		local filename = filename_prefix..file
		local succ, err = save_atomic_move_file(filename)
		if not succ and not first_error then
			first_error = err
		end
	end
	
	return not first_error, first_error -- either true,nil or nil,error
end


