-- railwaytime.lua
-- Advtrains uses a desynchronized time for train movement. Everything is counted relative to this time counter.
-- The advtrains-internal time is in no way synchronized to the real-life time, due to:
-- - Lag
-- - Server stops/restarts
-- However, this means that implementing a "timetable" system using the "real time" is not practical. Therefore,
-- we introduce a custom time system, the RWT(Railway Time), which has nothing to do with RLT(Real-Life Time)
-- RWT has a time cycle of 1 hour. This should be sufficient for most train lines that will ever be built in Minetest.
-- A RWT looks like this:    37;25
-- The ; is to distinguish it from a normal RLT (which has colons e.g. 12:34:56). Left number is minutes, right number is seconds.
-- The minimum RWT is 00;00, the maximum is 59;59.
-- It is OK to leave one places out at either end, esp. when writing relative times, such as:
-- 43;3   22;0   2;30   0;10  ;10
-- Those places are then filled with zeroes. Indeed, ";" would be valid for 00;00 .

--[[
1;23;45 = {
	s=45,
	m=23,
	c=1, -- Cycle(~hour), not displayed most time
}

]]

local rwt = {}

--Time Stamp (Seconds since start of world)
local e_time = 0

-- Current rw time, cached and updated each step
local crwtime

function rwt.set_time(t)
	e_time = t or 0
end

function rwt.get_time()
	return e_time
end

function rwt.step(dt)
	e_time = e_time + dt
end

function rwt.now()
	return rwt.from_sec(e_time)
end

function rwt.new(c, m, s)
	return {
		c = c or 0,
		m = m or 0,
		s = s or 0
	}
end
function rwt.copy(rwtime)
	return {
		c = rwtime.c or 0,
		m = rwtime.m or 0,
		s = rwtime.s or 0
	}
end

function rwt.from_sec(stime)
	local res = {}
	local seconds = atfloor(stime)
	res.s = seconds % 60
	local minutes = atfloor(seconds/60)
	res.m = minutes % 60
	res.c = atfloor(minutes/60)
	return res
end

function rwt.to_sec(rwtime, c_over)
	return (c_over or rwtime.c)*60*60 + rwtime.m*60 + rwtime.s
end

function rwt.add(t1, t2)
	local t1s = rwt.to_sec(t1)
	local t2s = rwt.to_sec(t1)
	return rwt.from_sec(t1s + t2s)
end

function rwt.add_secs(t1, t2s)
	local t1s = rwt.to_sec(t1)
	return rwt.from_sec(t1s + t2s)
end

-- How many seconds FROM t1 TO t2
function rwt.diff(t1, t2)
	local t1s = rwt.to_sec(t1)
	local t2s = rwt.to_sec(t1)
	return t2s - t1s
end

-- Subtract t2 from t1 (inverted argument order compared to diff())
function rwt.sub(t1, t2)
	return rwt.from_sec(rwt.diff(t2, t1))
end

-- Adjusts t2 by thresh and then returns time from t1 to t2
function rwt.adj_diff(t1, t2, thresh)
	local newc = rwt.adjust_cycle(t2, thresh, t1)
	local t1s = rwt.to_sec(t1)
	local t2s = rwt.to_sec(t2, newc)
	return t1s - t2s
end



-- Threshold values
-- "reftime" is the time to which this is made relative and defaults to now.
rwt.CA_FUTURE	= 60*60 - 1		-- Selected so that time lies at or in the future of reftime (at nearest point in time)
rwt.CA_FUTURES	= 60*60 		-- Same, except when times are equal, advances one full cycle
rwt.CA_PAST		= 0				-- Selected so that time lies at or in the past of reftime
rwt.CA_PASTS	= -1	 		-- Same, except when times are equal, goes back one full cycle
rwt.CA_CENTER	= 30*60			-- If time is within past 30 minutes of reftime, selected as past, else selected as future.

-- Adjusts the "cycle" value of a railway time to be in some relation to reftime.
-- Returns new cycle
function rwt.adjust_cycle(rwtime, reftime_p, thresh)
	local reftime = reftime_p or rwt.now()
	
	local reftimes = rwt.to_sec(reftime)
	
	local rwtimes = rwt.to_sec(rwtime, 0)
	local timeres = reftimes + thresh - rwtimes
	local cycles = atfloor(timeres / (60*60))

	return cycles
end

function rwt.adjust(rwtime, reftime, thresh)
	local cp = rwt.copy(rwtime)
	cp.c = rwt.adjust(rwtime, reftime, thresh)
	return cp
end

function rwt.to_string(rwtime, places)
	local pl = places or 2
	if rwtime.c~=0 or pl>=3 then
		return string.format("%d;%02d;%02d", rwtime.c, rwtime.m, rwtime.s)
	elseif rwtime.m~=0 or pl>=2 then
		return string.format("%02d;%02d", rwtime.m, rwtime.s)
	else
		return string.format(";%02d",rwtime.s)
	end
	return str
end

-- Useful for departure times: returns time (in seconds)
-- until the next (adjusted FUTURE) occurence of deptime is reached
-- in this case, rwtime is used as reftime and deptime should lie in the future of rwtime
-- rwtime defaults to NOW
function rwt.get_time_until(deptime, rwtime_p)
	local rwtime = rwtime_p or rwt.now()
	return rwt.adj_diff(rwtime, deptime, rwt.CA_FUTURE)
end



advtrains.lines.rwt = rwt
