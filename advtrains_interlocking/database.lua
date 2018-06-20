-- interlocking/database.lua
-- saving the location of TCB's, their neighbors and their state
--[[
The interlocking system is based on track circuits.
Track circuit breaks must be manually set by the user. Signals must be assigned to track circuit breaks and to a direction(connid).
To simplify the whole system, there is no overlap.
== Trains ==
Trains always occupy certain track circuits. These are shown red in the signalbox view (TRAIN occupation entry).
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
Not implemented (see note by reversible): OWNED - former ROUTE segments that a train has begun passing (train_id assigned)
		  - Space behind a train up to the next signal, when a TC is set as REVERSIBLE
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
Note: In SimSig, it is possible to set a route into an still occupied section on the victoria line sim. (at the depot exit at seven sisters), although
	there are still segments set ahead of the first train passing, remaining from another route.
	Because our system will be able to remember "requested routes" and set them automatically once ready, this is not necessary here.
== Call-On/Multiple Trains ==
It will be necessary to join and split trains using call-on routes. A call-on route may be set when:
- there are no ROUTE reservations
- there are TRAIN reservations only inside TCs that have "allow call-on" set
== TC Properties ==
Note: Reversible property will not be implemented, assuming everything as non-rev.
This is sufficient to cover all use cases, and is done this way in reality.
	REVERSIBLE - Whether trains are allowed to reverse while on track circuit
	This property is supposed to be set for station tracks, where there is a signal at each end, and for sidings.
	It should in no case be set for TCs covering turnouts, or for main running lines.
	When a TC is not set as reversible, the OWNED status is cleared from the TC right after the train left it,
	to allow other trains to pass it.
	If it is set reversible, interlocking will keep the OWNED state behind the train up to the next signal, clearing it
	as soon as the train passes another signal or enters a non-reversible section.
CALL_ON_ALLOWED - Whether this TC being blocked (TRAIN or ROUTE) does not prevent shunt routes being set through this TC
== More notes ==
- It may not be possible to switch turnouts when their TC has any state entry

== Route releasing (TORR) ==
A train passing through a route happens as follows:
Route set from entry to exit signal
Train passes entry signal and enters first TC past the signal
-> Route from signal cleared (TCs remain locked)
-> ROUTE status of first TC past signal cleared
Train continues along the route.
Whenever train leaves a TC
-> Clearing any routes set from this TC outward recursively - see "Reversing problem"
Whenever train enters a TC
-> Clear route status from the just entered TC
== Reversing Problem ==
Encountered at the Royston simulation in SimSig. It is solved there by imposing a time limit on the set route. Call-on routes can somehow be set anyway.
Imagine this setup: (T=Train, R=Route, >=in_dir TCB)
    O-|  Royston P2 |-O
T->---|->RRR-|->RRR-|--
Train T enters from the left, the route is set to the right signal. But train is supposed to reverse here and stops this way:
    O-|  Royston P2 |-O
------|-TTTT-|->RRR-|--
The "Route" on the right is still set. Imposing a timeout here is a thing only professional engineers can determine, not an algorithm.
    O-|  Royston P2 |-O
<-T---|------|->RRR-|--
The train has left again, while route on the right is still set.
So, we have to clear the set route when the train has left the left TC.
This does not conflict with call-on routes, because both station tracks are set as "allow call-on"
Because none of the routes extends past any non-call-on sections, call-on route would be allowed here, even though the route
is locked in opposite direction at the time of routesetting.
Another case of this:
--TTT/--|->RRR--
The / here is a non-interlocked turnout (to a non-frequently used siding). For some reason, there is no exit node there,
so the route is set to the signal at the right end. The train is taking the exit to the siding and frees the TC, without ever
having touched the right TC.
]]--

local TRAVERSER_LIMIT = 100


local ildb = {}

local track_circuit_breaks = {}

function ildb.load(data)

end

function ildb.save()
	return {}
end

--
--[[
TCB data structure
{
[1] = { -- Variant: with adjacent TCs.
	== Synchronized properties == Apply to the whole TC
	adjacent = { <signal specifier>,... } -- Adjacent TCBs, forms a TC with these
	conflict = { <signal specifier>,... } -- Conflicting TC's (chosen as a representative TCB member)
	-- Used e.g. for crossing rails that do not have nodes in common (like it's currently done)
	incomplete = <boolean> -- Set when the recursion counter hit during traverse. Probably needs to add
	-- another tcb at some far-away place
	route = {origin = <signal>, in_dir = <boolean>}
	-- Set whenever a route has been set through this TC. It saves the origin tcb id and side
	-- (=the origin signal). in_dir is set when the train will enter the TC from this side
	
	== Unsynchronized properties == Apply only to this side of the TC
	signal = <pos> -- optional: when set, routes can be set from this tcb/direction and signal
	-- aspect will be set accordingly.
	routetar = <signal> -- Route set from this signal. This is the entry that is cleared once
	-- train has passed the signal. (which will set the aspect to "danger" again)
	route_committed = <boolean> -- When setting/requesting a route, routetar will be set accordingly,
	-- while the signal still displays danger and nothing is written to the TCs
	-- As soon as the route can actually be set, all relevant TCs and turnouts are set and this field
	-- is set true, clearing the signal
},
[2] = { -- Variant: end of track-circuited area (initial state of TC)
	end_of_interlocking = true,
	section_free = <boolean>, --this can be set by an exit node via mesecons or atlatc, 
	-- or from the tc formspec.
}
}
Signal specifier (a pair of TCB/Side):
{p = <pos>, s = <1/2>}
]]


--
function ildb.create_tcb(pos)
	local new_tcb = {
		[1] = {end_of_interlocking = true},
		[2] = {end_of_interlocking = true},
	}
	local pts = advtrains.roundfloorpts(pos)
	track_circuit_breaks[pts] = new_tcb
end

function ildb.get_tcb(pos)
	local pts = advtrains.roundfloorpts(pos)
	return track_circuit_breaks[pts]
end

-- This function will actually handle the node that is in connid direction from the node at pos
-- so, this needs the conns of the node at pos, since these are already calculated
local function traverser(found_tcbs, pos, conns, connid, count)
	local adj_pos, adj_connid, conn_idx, nextrail_y, next_conns = advtrains.get_adjacent_rail(pos, conns, connid, advtrains.all_tracktypes)
	if not adj_pos then
		-- end of track
		return
	end
	-- look whether there is a TCB here
	if #next_conns == 2 then --if not, don't even try!
		local tcb = ildb.get_tcb(adj_pos)
		if tcb then
			-- done with this branch
			table.insert(found_tcbs, {p=adj_pos, s=adj_connid})
			return
		end
	end
	-- recursion abort condition
	if count > TRAVERSER_LIMIT then
		atdebug("Traverser hit counter at",adj_pos, adj_connid,"found tcb's:",found_tcbs)
		return true
	end
	-- continue traversing
	local counter_hit = false
	for nconnid, nconn in ipairs(next_conns) do
		if adj_connid ~= nconnid then
			counter_hit = counter_hit or traverser(found_tcbs, adj_pos, next_conns, nconnid, count + 1, hit_counter)
		end
	end
	return counter_hit
end

local function sigd_equal(sigd, cmp)
	return vector.equals(sigd.p, cmp.p) and sigd.s==cmp.s
end





-- Updates the neighbors of this TCB using the traverser function (see comments above)
-- returns true if the traverser hit the counter, which means that there could be another
-- TCB outside of the traversed range.
function ildb.update_tcb_neighbors(pos, connid)
	local found_tcbs = { {p = pos, s = connid} }
	local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
	if not node_ok then
		error("update_tcb_neighbors but node is NOK: "..minetest.pos_to_string(pos))
	end
	
	local counter_hit = traverser(found_tcbs, pos, conns, connid, 0, hit_counter)
	
	for idx, sigd in pairs(found_tcbs) do
		local tcb = ildb.get_tcb(sigd.p)
		local tcbs = tcb[sigd.s]
		
		tcbs.end_of_interlocking = nil
		tcbs.incomplete = counter_hit
		tcbs.adjacent = {}
		
		for idx2, other_sigd in pairs(found_tcbs) do
			if idx~=idx2 then
				ildb.add_adjacent(tcbs, sigd.p, sigd.s, other_sigd)
			end
		end
	end
	
	return hit_counter
end

-- Add the adjacency entry into the tcbs, but without duplicating it
-- and without adding a self-reference
function ildb.add_adjacent(tcbs, this_pos, this_connid, sigd)
	if sigd_equal(sigd, {p=this_pos, s=this_connid}) then
		return
	end
	tcbs.end_of_interlocking = nil
	if not tcbs.adjacent then
		tcbs.adjacent = {}
	end
	for idx, cmp in pairs(tcbs.adjacent) do
		if sigd_equal(sigd, cmp) then
			return
		end
	end
	table.insert(tcbs.adjacent, sigd)
end

advtrains.interlocking.db = ildb




