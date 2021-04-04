# serialize_lib API

## Serialization Library (serialize.lua)

### config table

Serialization functions accept a config table. Currently only one configuration option is defined.

    config = {
        	skip_empty_tables = false
        	-- used for write_to_fd/write_to_file
        	-- if true, does not store empty tables
        	-- On next read, keys that mapped to empty tables resolve to nil
    }

If you want to use all-default config options, you can pass `nil` as the config parameter.

### Serialization limits

  * Only strings, booleans, numbers and tables can be serialized, no functions or userdata
  * serialize_lib requires that no reference loops are present in the table to be serialized. Currently, when passing a table that has a reference loop, serialize_lib will produce a stack overflow.

### Functions

All of these functions call `error(<message>)` if an error occurs. Errors can be caught with `pcall()`.

#### write_to_fd(root_table, file, config)
Writes the contents of `root_table` to the file from the file handle given by `file`, and closes the file descriptor afterwards.

#### write_to_file(root_table, filename, config)
First, opens `filename` for write. Then, writes the contents of `root_table` to the file.

#### read_from_fd(file)
Reads the file from the file handle given by `file`, and closes the file descriptor afterwards. Returns the deserialized table.

#### read_from_file(filename)
First, opens `filename` for read. Then, reads the file and returns the deserialized table.

### External Lua Module
serialize.lua can be loaded as a standard Lua module even outside Minetest, like this:

    local serialize = require("serialize")

## General API

### Minetest wrappers for serialization functions

Serialize_lib wraps write_to_file and read_from_file into 2 functions that do not throw errors but instead log the fact to the server log and have an appropriate return value:

#### serialize_lib.write_table_to_file(root_table, filename)

Serializes `root_table` into `filename`. On success, returns true. On failure, logs the error, then returns false and the error message.

#### serialize_lib.read_table_from_file(filename)

Deserializes the given file. On success, returns the deserialized table. On failure, logs the error, then returns false and the error message.

## Atomic API

serialize_lib provides functions for atomic saving. This means that if the process is interrupted during writing the save file, it is ensured that no save data gets corrupted and that instead the old state is read.

The atomic system is flexible, and can be used not only to save serialized Lua tables but arbitrary file formats by means of a callback function. This callback function gets passed a file descriptor to operate on.

### Concept
The plain scheme just overwrites the file in place. This however poses problems when we are interrupted right within the write, so we have incomplete data. So, the following scheme is applied:

Unix:

 1. writes to `filename.new`
 2. moves `filename.new` to `filename`, clobbering previous file
 
Windows:

 1. writes to `filename.new`
 2. delete `filename`
 3. moves `filename.new` to `filename`

We count a new version of the state as "committed" after stage 2.

During loading, we apply the following order of precedence:

 1. `filename`
 2. `filename.new` (windows only, in case we were interrupted just before 3. when saving)

### Functions

All of these functions return either true on success or nil, error on error.

#### serialize_lib.load_atomic(filename, callback)

Load a saved state.

If 'callback' is nil: reads serialized table. Returns the read table, or nil,err on error.

If 'callback' is a function (signature `func(file_handle)` ): Counterpart to save_atomic with function argument. Opens the file and calls callback on it. If the callback function throws an error, and strict loading is enabled, that error is propagated. The callback's first return value is returned by load_atomic.

#### serialize_lib.save_atomic(data, filename, callback, config)

Save a file atomically.

'data' is the data to be saved (when a callback is used, this can be nil)

If 'callback' is nil: 'data' must be a table, and is serialized into the file

If 'callback' is a function (signature `func(data, file_handle)` ): Opens the file and calls callback on it. The 'data' argument is the data passed to save_atomic(). If the callback function throws an error, and strict loading is enabled, that error is propagated. The callback's first return value is returned by load_atomic().

Important: the callback must close the file in all cases!

#### serialize_lib.save_atomic_multiple(parts_table, filename_prefix, callbacks_table, config)

Saves multiple files synchronously. First writes all data to all `filename`.new files, then moves all files in quick succession to avoid inconsistent backups. parts_table is a table where the keys are used as part of the filename and the values are the respective data written to it.

  * Example: if `parts_table={foo={...}, bar={...}}`, then `filename_prefix`foo and `filename_prefix`bar are written out.

If 'callbacks_table' is defined, it is consulted for callbacks the same way save_atomic does.

  * Example: if `callbacks_table = {foo = func()...}`, then the callback is used during writing of file 'foo' (but not for 'bar')
  * Note however that you must at least insert a "true" in the parts_table if you don't use the data argument.

Important: the callback must close the file in all cases!
