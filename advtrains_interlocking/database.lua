-- interlocking/database.lua
-- saving the location of TCB's, their neighbors and their state
--[[
The interlocking system is based on track circuits.
Track circuit breaks must be manually set by the user. Signals must be assigned to track circuit breaks and to a direction(connid).
To simplify the whole system, there is no overlap.
== Trains ==
A train always reserves the space between two signals facing it. All track circuits in this space
have a reservation entry TRAIN with the train's ID
== Database storage ==
The things that are actually saved are the Track Circuit Breaks. Each TCB holds a list of the TCBs that are adjacent in each direction.
TC occupation/state is then saved inside each (TCB,Direction) and held in sync across all TCBs adjacent to this one. If something should not be in sync,
all entries are merged to perform the most restrictive setup.
== Traverser function ==
To determine and update the list of neighboring TCBs, we need a traverser function.
It will start at one TCB in a specified direction (connid) and use get_adjacent_rail to crawl along the track. When encountering a turnout or a crossing,
it needs to branch(call itself recursively) to find all required TCBs. Those found TCBs are then saved in a list as tuples (TCB,Dir)
In the last step, they exchange their neighbors.
== TC states ==
A track circuit does not have a state as such, but has more or less a list of "reservations"
type can be one of these:
TRAIN See Trains obove
ROUTE Route set from a signal, but no train has yet passed that signal.
Certain TCs can be marked as "allow call-on".
== Route setting: ==
Routes are set from a signal (the entry signal) to another signal facing the same direction (the exit signal)
Remember that signals are assigned to a TCB and a connid.
Whenever this is done, the following track circuits are set "reserved" by the train by saving the entry signal's ID:
- all TCs on the direct way of the route - set as ROUTE
Route setting fails whenever any TC that we want to set ROUTE to is already set ROUTE or TRAIN from another signal (except call-on, see below)
Apart from this, we need to set turnouts
- Turnouts on the track are set held as ROUTE
- Turnouts that purpose as flank protection are set held as FLANK (NOTE: left as an idea for later, because it's not clear how to do this properly without an engineer)
== Call-On/Multiple Trains ==
It will be necessary to join and split trains using call-on routes. A call-on route may be set when:
- there are no ROUTE reservations
- there are TRAIN reservations only inside TCs that have "allow call-on" set


== More notes ==
- It may not be possible to switch turnouts when their TC has any state entry

]]--



