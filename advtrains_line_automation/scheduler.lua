-- scheduler.lua
-- Implementation of a Railway time schedule queue
-- In contrast to the LuaATC interrupt queue, this one can handle many different
-- event receivers. This is done by registering a callback with the scheduler

local ln = advtrains.lines
local sched = {}

local UNITS_THRESH = 10
local MAX_PER_ITER = 10

local callbacks = {}
--Function signature is function(d)
function sched.register_callback(e, func)
	callbacks[e] = func
end

--[[
{
	t = <railway time in seconds>
	e = <handler callback>
	d = <data table>
	u = <unit identifier>
}
The "unit identifier" is there to prevent schedule overflows. It can be, for example, the position hash
of a node or a train ID. If the number of schedules for a unit exceeds UNITS_THRESH, further schedules are
blocked.
]]--
local queue = {}

local units_cnt = {}

function sched.load(data)
	if data then
		for i,elem in ipairs(data) do
			table.insert(queue, elem)
			units_cnt[elem.u] = (units_cnt[elem.u] or 0) + 1
		end
	end
end
function sched.save()
	return queue
end

function sched.run()
	local ctime = ln.rwt.get_time()
	local cnt = 0
	local ucn, elem
	while cnt <= MAX_PER_ITER do
		elem = queue[1]
		if elem and elem.t <= ctime then
			table.remove(queue, 1)
			if callbacks[elem.e] then
				-- run it
				callbacks[elem.e](elem.d)
			else
				atwarn("No callback to handle schedule",elem)
			end
			cnt=cnt+1
			ucn = units_cnt[elem.u]
			if ucn and ucn>0 then
				units_cnt[elem.u] = ucn - 1
			end
		else
			break
		end
	end
end

function sched.enqueue(rwtime, handler, evtdata, unitid, unitlim)
	local qtime = ln.rwt.to_secs(rwtime)
	assert(type(handler)=="string")
	assert(type(unitid)=="string")
	assert(type(unitlim)=="number")
	
	local cnt=1
	local ucn, elem
	
	ucn = (units_cnt[unitid] or 0)
	local ulim=(unitlim or UNITS_THRESH)
	if ucn >= ulim then
		atwarn("Scheduler: discarding enqueue for",handler,"(limit",ulim,") because unit",unitid,"has already",ucn,"schedules enqueued")
		return false
	end
	
	while true do
		elem = queue[cnt]
		if not elem or elem.t > qtime then
			table.insert(queue, cnt, {
					t=qtime,
					e=handler,
					d=evtdata,
					u=unitid,
				})
			units_cnt[unitid] = ucn + 1
			return true
		end
		cnt = cnt+1
	end
end

function sched.enqueue_in(rwtime, handler, evtdata, unitid, unitlim)
	local ctime = ln.rwt.get_time()
	sched.enqueue(ctime + rwtime, handler, evtdata, unitid, unitlim)
end

ln.sched = sched
