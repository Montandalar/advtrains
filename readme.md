# serialize_lib
A Minetest mod library for safely storing large amounts of data in on-disk files.
Created out of the need to have a robust data store for advtrains.

The main purpose is to load and store large Lua table structures into files, without loading everything in memory and exhausting the function constant limit of LuaJIT.

Also contains various utilities to handle files on disk in a safe manner, retain multiple versions of the same file a.s.o.

## API documentation

For API documentation, see `api.md`.

## Configuration

serialize_lib includes two configuration options:

### serialize_lib_strict_loading (Strict loading)
  * Type: boolean
  * Default: false

Enable strict file loading mode

If enabled, if any error occurs during loading of a file using the 'atomic' API, an error is thrown. You probably need to disable this option for initial loading after creating the world.

### serialize_lib_no_auto_windows_mode (No automatic Windows Mode)
  * Type: boolean
  * Default: false

Do not automatically switch to "Windows mode" when saving atomically

Normally, when renaming filename.new to filename fails, serialize_lib automatically switches to a mode where it deletes filename prior to moving. Enable this option to prevent this behavior and abort saving instead.

## License
serialize_lib
Copyright (C) 2020-2021 orwell96

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.