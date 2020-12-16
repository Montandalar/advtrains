# serialize_lib
A Minetest mod library for safely storing large amounts of data in on-disk files.
Created out of the need to have a robust data store for advtrains.

The main purpose is to load and store large Lua table structures into files, without loading everything in memory and exhausting the function constant limit of LuaJIT.

Also contains various utilities to handle files on disk in a safe manner, retain multiple versions of the same file a.s.o.