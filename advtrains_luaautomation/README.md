
# Advtrains - Lua Automation features

This mod offers components that run LUA code and interface with each other through a global environment. It makes complex automated railway systems possible. The mod is sometimes abbreviated as 'LuaATC' or 'atlatc'. This stands for AdvTrainsLuaATC. This short name has been chosen for user convenience, since the name of this mod ('advtrains_luaautomation') is very long.

A probably more complete documentation of LuaATC is found on the [Advtrains Wiki](http://advtrains.de/wiki/doku.php?id=usage:atlatc:start)

## Privileges
To perform any operations using this mod (except executing operation panels), players need the "atlatc" privilege.
This privilege should never be granted to anyone except trusted administrators. Even though the LUA environment is sandboxed, it is still possible to DoS the server by coding infinite loops or requesting expotentially growing interrupts. 

## Environments

Each active component is assigned to an environment where all atlac data is held. Components in different environments can't inferface with each other.
This system allows multiple independent automation systems to run simultaneously without polluting each other's environment.

 - `/env_create <env_name>`:
Create environment with the given name. To be able to do anything, you first need to create an environment. Choose the name wisely, you can't change it afterwards without deleting the environment and starting again.

 - `/env_setup <env_name>`:
Invoke the form to edit the environment's initialization code. For more information, see the section on active components. You can also delete an environment from here.

 - `/env_subscribe <env_name>`, `/env_unsubscribe <env_name>`:
Subscribe or unsubscribe from log/error messages originating from this environment

 - `/env_subscriptions [env_name]`:
List your subscriptions or players subscribed to an environment.


## Functions and variables
### General Functions and Variables
The following standard Lua libraries are available:
 - `string`
 - `math`
 - `table`
 - `os`
 
The following standard Lua functions are available:
 - `assert`
 - `error`
 - `ipairs`
 - `pairs`
 - `next`
 - `select`
 - `tonumber`
 - `tostring`
 - `type`
 - `unpack`

Any attempt to overwrite the predefined values results in an error.

### LuaAutomation Global Variables
 - `S`
The variable 'S' contains a table which is shared between all components of the environment. Its contents are persistent over server restarts. May not contain functions, every other value is allowed.

 - `F`
The variable 'F' also contains a table which is shared between all components of the environment. Its contents are discarded on server shutdown or when the init code gets re-run. Every data type is allowed, even functions.
The purpose of this table is not to save data, but to provide static value and function definitions. The table should be populated by the init code.

### LuaAutomation Global Functions
> Note: in the following functions, all parameters named `pos` designate a position. You can use the following:  
> - a default Minetest position vector (eg. {x=34, y=2, z=-18})  
> - the POS(34,2,-18) shorthand below.  
> - A string, the passive component name. See 'passive component naming'. 
  


 - `POS(x,y,z)`
Shorthand function to create a position vector {x=?, y=?, z=?} with less characters.

 - `getstate(pos)`
Get the state of the passive component at position `pos`.

 - `setstate(pos, newstate)`
Set the state of the passive component at position `pos`.

 - `is_passive(pos)`
Checks whether there is a passive component at the position pos (and/or whether a passive component with this name exists)

 - `interrupt(time, message)`
Cause LuaAutomation to trigger an `int` event on this component after the given time in seconds with the specified `message` field. `message` can be of any Lua data type. Returns true. *Not available in init code.*

 - `interrupt_safe(time, message)`
Like `interrupt()`, but does not add an interrupt and returns false when an interrupt (of any type) is already present for this component. Returns true when interrupt was successfully added.

 - `interrupt_pos(pos, message)`
Immediately trigger an `ext_int` event on the active component at position pos. `message` is like in interrupt(). Use with care, or better **_don't use_**! Incorrect use can result in **_expotential growth of interrupts_**.

 - `clear_interrupts()`
Removes any pending interrupts of this node.

 - `digiline_send(channel, message)`
Make this active component send a digiline message on the specified channel.
Not available in init code.

 - `atc_send_to_train(<train_id>, <atc_command>)`
	Sends the specified ATC command to the train specified by its train id. This happens regardless of where the train is in the world, and can be used to remote-control trains. Returns true on success. If the train ID does not exist, returns false and does nothing. See [atc_command.txt](../atc_command.txt) for the ATC command syntax.

#### Interlocking Route Management Functions
If `advtrains_interlocking` is enabled, the following aditional functions can be used:

 - `can_set_route(pos, route_name)`
Returns whether it is possible to set the route designated by route_name from the signal at pos.

 - `set_route(pos, route_name)`
Requests the given route from the signal at pos. Has the same effect as clicking "Set Route" in the signalling dialog.

 - `cancel_route(pos)`
Cancels the route that is set from the signal at pos. Has the same effect as clicking "Cancel Route" in the signalling dialog.

 - `get_aspect(pos)`
Returns the signal aspect of the signal at pos. A signal aspect has the following format:
```lua
asp = {
	main = <int speed>,
		-- Main signal aspect, tells state and permitted speed of next section
		-- 0 = section is blocked
		-- >0 = section is free, speed limit is this value
		-- -1 = section is free, maximum speed permitted
		-- false = Signal doesn't provide main signal information, retain current speed limit.
	shunt = <boolean>,
		-- Whether train may proceed as shunt move, on sight
		-- main aspect takes precedence over this
		-- When main==0, train switches to shunt move and is restricted to speed 8
	proceed_as_main = <boolean>,
		-- If an approaching train is a shunt move and 'shunt' is false,
		-- the train may proceed as a train move under the "main" aspect
		-- if the main aspect permits it (i.e. main!=0)
		-- If this is not set, shunt moves are NOT allowed to switch to
		-- a train move, and must stop even if "main" would permit passing.
		-- This is intended to be used for "Halt for shunt moves" signs.
	
	dst = <int speed>,
		-- Distant signal aspect, tells state and permitted speed of the section after next section
		-- The character of these information is purely informational
		-- At this time, this field is not actively used
		-- 0 = section is blocked
		-- >0 = section is free, speed limit is this value
		-- -1 = section is free, maximum speed permitted
		-- false = Signal doesn't provide distant signal information.
	
	-- the character of call_on and dead_end is purely informative
	call_on = <boolean>, -- Call-on route, expect train in track ahead (not implemented yet)
	dead_end = <boolean>, -- Route ends on a dead end (e.g. bumper) (not implemented yet)

	w_speed = <integer>,
	-- "Warning speed restriction". Supposed for short-term speed
	-- restrictions which always override any other restrictions
	-- imposed by "speed" fields, until lifted by a value of -1
	-- (Example: german Langsamfahrstellen-Signale)
}
```
As of January 2020, the 'dst', 'call_on' and 'dead_end' fields are not used.

#### Lines

The advtrains_line_automation component adds a few contraptions that should make creating timeable systems easier.
Part of its functionality is also available in LuaATC:

- `rwt.*` - all Railway Time functions are included as documented in [the wiki](https://advtrains.de/wiki/doku.php?id=dev:lines:rwt)

 - `schedule(rw_time, msg)`, `schedule_in(rw_dtime, msg)`
Schedules an event of type {type="schedule", schedule=true, msg=msg} at (resp. after) the specified railway time (which can be in any format). You can only schedule one event this way. (uses the new lines-internal scheduler)

Note: Using the lines scheduler is preferred over using `interrupt()`, as it's more performant and safer to use.

## Events
The event table is a variable created locally by the component being triggered. It is a table with the following format:
```lua
event = {
	type = "<event type>",
	<event type> = true,
	--additional event-specific content
}
```
You can check the event type by using the following:
```lua 
if event.type == "wanted" then
	--do stuff
end
```
or
```lua
if event.wanted then
	--do stuff
end
```
where `wanted` is the event type to check for.  
See the "Active Components" section below for details on the various event types as not all of them are applicable to all components.

## Components
Atlac components introduce automation-capable components that fall within two categories:
 - Active Components are components that are able to run Lua code, triggered by specific events.
 - Passive Components can't perform actions themselves. Their state can be read and set by active components or manually by the player.

### Lua ATC Rails
Lua ATC rails are the only components that can actually interface with trains. The following event types are available to the Lua ATC rails:
 - `{type="train", train=true, id="<train_id>"}`
	* This event is fired when a train enters the rail. The field `id` is the unique train ID, which is 6-digit random numerical string.
	* If the world contains trains from an older advtrains version, this string may be longer and contain a dot `.`

 - `{type="int", int=true, msg=<message>}`
	* Fired when an interrupt set by the `interrupt` function runs out. `<message>` is the message passed to the interrupt function.
	* For backwards compatiblity reasons, `<message>` is also contained in an `event.message` variable.

 - `{type="ext_int", ext_int=true, message=<message>}`
	* Fired when another node called `interrupt_pos` on this position. `message` is the message passed to the interrupt_pos function.

 - `{type="digiline", digiline=true, channel=<channel>, msg=<message>}`
	* Fired when the controller receives a digiline message.

#### Basic Lua Rail Functions and Variables
In addition to the above environment functions, the following functions are available to whilst the train is in contact with the LuaATC rail:

 - `atc_send(<atc_command>)`
	Sends the specified ATC command to the train (a string) and returns true. If there is no train, returns false and does nothing. See [atc_command.txt](../atc_command.txt) for the ATC command syntax.

 - `atc_reset()`
	Resets the train's current ATC command. If there is no train, returns false and does nothing.

 - `atc_arrow`
	Boolean, true when the train is driving in the direction of the arrows of the ATC rail. Nil if there is no train.

 - `atc_id`
	Train ID of the train currently passing the controller. Nil if there's no train.

 - `atc_speed`
	Speed of the train, or nil if there is no train.

 - `atc_set_text_outside(text)`
	Set text shown on the outside of the train. Pass nil to show no text. `text` must be a string.

 - `atc_set_text_inside(text)`
	Set text shown to train passengers. Pass nil to show no text. `text` must be a string.

 - `atc_set_text_inside(text) / atc_set_text_outside(text)`
	Getters for inside/outside text, return nil when no train is there.

 - `get_line()`
	Returns the "Line" property of the train (a string).
	This can be used to distinguish between trains of different lines and route them appropriately.
	The interlocking system also uses this property for Automatic Routesetting.

 - `set_line(line)`
	Sets the "Line" property of the train (a string).
	If the first digit of this string is a number (0-9), any subway wagons on the train (from advtrains_train_subway) will have this one displayed as line number
	(where "0" is actually shown as Line 10 on the train)

 - `get_rc()`
	Returns the "Routingcode" property of the train (a string).
	The interlocking system uses this property for Automatic Routesetting.

 - `set_rc(routingcode)`
	Sets the "Routingcode" property of the train (a string).
	The interlocking system uses this property for Automatic Routesetting.

#### Shunting Functions and Variables
There are several functions available especially for shunting operations. Some of these functions make use of Freight Codes (FC) set in the Wagon Properties of each wagon and/or locomotive:

 - `split_at_index(index, atc_command)`
	Splits the train at the specified index, into a train with index-1 wagons and a second train starting with the index-th wagon. The `atc_command` specified is sent to the second train after decoupling. `"S0"` or `"B0"` is common to ensure any locomotives in the remaining train don't continue to move.
	
	`index` must be more than 1 to avoid trying to decouple the very front of a train.
	
	Example: train has wagons `"foo","foo","foo","bar","bar","bar"`  
	Command: `split_at_index(4,"S0")`  
	Result: first train (continues at previous speed): `"foo","foo","foo"`, second train (slows at S0): `"bar","bar","bar"`

 - `split_at_fc(atc_command, len)`
	Splits the train in such a way that all cars with non-empty current FC of the first part of the train have the same FC. The
	`atc_command` specified is sent to the rear part, as with	split_at_index. It returns the fc of the cars of the first part.
	
	Example : Train has current FCs `"" "" "bar" "foo" "bar"`  
	Command: `split_at_fc(<atc_command>)`  
	Result: `train "" "" "bar"` and `train "foo" "bar"`  
	The function returns `"bar"` in this case.

	The optional argument `len` specifies the maximum length for the
	first part of the train.  
	Example: Train has current FCs `"foo" "foo" "foo" "foo" "bar" "bar"`  
	Command: `split_at_fc(<atc_command>,3)`  
	Result: `"foo" "foo" "foo"` and `"foo" "bar" "bar"`  
	The function returns `"foo"` in this case.

 - `split_off_locomotive(command, len)`
	Splits off the locomotives at the front of the train, which are
	identified by an empty FC. `command` specifies the ATC command to be
	executed by the rear half of the train. The optional argument `len` specifies the maximum length for the
	first part of the train as above.

 - `step_fc()`
	Steps the FCs of all train cars forward. FCs are composed of codes
	separated by exclamation marks (`!`), for instance
	`"foo!bar!baz"`. Each wagon has a current FC, indicating its next
	destination. Stepping the freight code forward, selects the next
	code after the !. If the end of the string is reached, then the
	first code is selected, except if the string ends with a question
	mark (`?`), then the order is reversed.


 - `train_length()`
	returns the number of cars the train is composed of.

 - `set_autocouple()`
	Sets the train into autocouple mode. The train will couple to the next train it collides with.

 - `unset_autocouple()`
	Unsets autocouple mode

Deprecated:

 - `set_shunt()`, `unset_shunt()`
	deprecated aliases for set_autocouple() and unset_autocouple(), will be removed from a later release.


#### Interlocking
This additional function is available when advtrains_interlocking is enabled:

 - `atc_set_ars_disable(boolean)`
	Disables (true) or enables (false) the use of ARS for this train. The train will not trigger ARS (automatic route setting) on signals then.
	
	Note: If you want to disable ARS from an approach callback, the call to `atc_set_ars_disable(true)` *must* happen during the approach callback, and may not be deferred to an interrupt(). Else the train might trigger an ARS before the interrupt fires.

#### Approach callbacks
The LuaATC interface provides a way to hook into the approach callback system, which is for example used in the TSR rails (provided by advtrains_interlocking) or the station tracks (provided by advtrains_lines). However, for compatibility reasons, this behavior needs to be explicitly enabled.

Enabling the receiving of approach events works by setting a variable in the local environment of the ATC rail, by inserting the following code:

```lua
__approach_callback_mode = 1
-- to receive approach callbacks only in arrow direction
-- or alternatively
__approach_callback_mode = 2
-- to receive approach callbacks in both directions
```

The following event will be emitted when a train approaches:
```lua
{type="approach", approach=true, id="<train_id>"}
```

Please note these important considerations when using approach callbacks:

 - Approach events might be generated multiple times for the same approaching train. If you are using atc_set_lzb_tsr(), you need to call this function on every run of the approach callback, even if you issued it before for the same train.
 - A reference to the train is available while executing this event, so that functions such as atc_send() or atc_set_text_outside() can be called. On any consecutive interrupts, that reference will no longer be available until the train enters the track ("train" event)
 - Unlike all other callbacks, approach callbacks are executed synchronous during the train step. This may cause unexpected side effects when performing certain actions (such as switching turnouts, setting signals/routes) from inside such a callback. I strongly encourage you to only run things that are absolutely necessary at this point in time, and defer anything else to an interrupt(). Be aware that certain things might trigger unexpected behavior.

Operations that are safe to execute in approach callbacks:

 - anything related only to the global environment (setting things in S)
 - digiline_send()
 - atc_set_text_*()
 - atc_set_lzb_tsr() (see below)

In the context of approach callbacks, one more function is available:

 - `atc_set_lzb_tsr(speed)`
Impose a Temporary Speed Restriction at the location of this rail, making the train pass this rail at the specified speed. (Causes the same behavior as the TSR rail)

#### Timetable Automation

The advtrains_line_automation component adds a few contraptions that should make creating timeable systems easier.
Part of its functionality is also available in LuaATC:

- `rwt.*`
All Railway Time functions are included as documented in https://advtrains.de/wiki/doku.php?id=dev:lines:rwt

- `schedule(rw_time, msg)`
- `schedule_in(rw_dtime, msg)`
Schedules the following event `{type="schedule", schedule=true, msg=msg}` at (resp. after) the specified railway time (which can be in any format). You can only schedule one event this way. Uses the new lines-internal scheduler.

### Operator panel
This simple node executes its actions when punched. It can be used to change a switch and update the corresponding signals or similar applications. It can also be connected to by the`digilines` mod.

The event fired is `{type="punch", punch=true}` by default. In case of an interrupt or a digiline message, the events are similar to the ones of the ATC rail.

### Init code
The initialization code is not a component as such, but rather a part of the whole environment. It can (and should) be used to make definitions that other components can refer to.  
A basic example function to define behavior for trains in stations:
```lua
function F.station(station_name)
	if event.train then
		atc_send("B0WOL")
		atc_set_text_inside(station_name)
		interrupt(10,"depart")
	end
	if event.int and event.message="depart" then
		atc_set_text_inside("") --an empty string clears the displayed text
		atc_send("OCD1SM")
	end
end
```

The corresponding Lua ATC Rail(s) would then contain the following or similar:  
```lua
F.station("Main Station")
```

The init code is run whenever the F table needs to be refilled with data. This is the case on server startup and whenever the init code is changed and you choose to run it.
The event table of the init code is always `{type="init", init=true}` and can not be anything else.  
Functions are run in the environment of the currently active node, regardless of where they were defined.

### Passive components

All passive components can be interfaced with the `setstate()` and `getstate()` functions (see above).
Each node below has been mapped to specific "states":

#### Signals
The red/green light signals `advtrains:signal_on/off` are interfaceable. Others such as `advtrains:retrosignal_on/off` are not. If advtrains_interlocking is enabled, trains will obey the signal if the influence point is set.

 - "green" - Signal shows green light
 - "red" - Signal shows red light

#### Switches/Turnouts
All default rail switches are interfaceable, independent of orientation.

 - "cr" The switch is set in the direction that is not straight.
 - "st" The switch is set in the direction that is straight.

The "Y" and "3-Way" switches have custom states. Looking from the convergence point:

 - "l" The switch is set towards the left.
 - "c" The switch is set towards the center (3-way only).
 - "r" The switch is set towards the right.


#### Mesecon Switch
The Mesecon switch can be switched using LuaAutomation. Note that this is not possible on levers or protected mesecon switches, only the unprotected full-node 'Switch' block `mesecons_switch:mesecon_switch_on/off`.

 - "on" - the switch is switched on.
 - "off" - the switch is switched off.

#### Andrew's Cross

 - "on" - it blinks.
 - "off" - it does not blink.

#### Passive Component Naming
You can assign names to passive components using the Passive Component Naming tool.
Once you set a name for any component, you can reference it by that name in the `getstate()` and `setstate()` functions.  
This way, you don't need to memorize positions.

Example: signal named `"Stn_P1_out"` at `(1,2,3)`  
Use `setstate("Stn_P1_out", "green")` instead of `setstate(POS(1,2,3), "green")`

If `advtrains_interlocking` is enabled, PC-Naming can also be used to name interlocking signals for route setting via the `set_route()` functions.  
**Important**: The "Signal Name" field in the signalling formspec is completely independent from PC-Naming and can't be used to look up the position. You need to explicitly use the PC-Naming tool.

