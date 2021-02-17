-- interrupt.lua
-- implements interrupt queue

--to be saved: pos and evtdata
local iq={}
local queue={}
local timer=0
local run=false

function iq.load(data)
	local d=data or {}
	queue = d.queue or {}
	timer = d.timer or 0
end
function iq.save()
	return {queue = queue, timer=timer}
end

function iq.has_at_pos(pos)
	for i=1,#queue do
		local qe=queue[i]
		if vector.equals(pos, qe.p) then
			return true
		end
	end
	return false
end

function iq.clear_ints_at_pos(pos)
	local i=1
	while i<=#queue do
		local qe=queue[i]
		if not qe then
			table.remove(queue, i)
		elseif vector.equals(pos, qe.p) and (qe.e.int or qe.e.ext_int) then
			table.remove(queue, i)
		else
			i=i+1
		end
	end
end

function iq.add(t, pos, evtdata)
	queue[#queue+1]={t=t+timer, p=pos, e=evtdata}
	run=true
end

function iq.mainloop(dtime)
	timer=timer + math.min(dtime, 0.2)
	local i=1
	while i<=#queue do
		local qe=queue[i]
		if not qe then
			table.remove(queue, i)
		elseif timer>qe.t then
			table.remove(queue, i)
			local pos, evtdata=qe.p, qe.e
			local node=advtrains.ndb.get_node(pos)
			local ndef=minetest.registered_nodes[node.name]
			if ndef and ndef.luaautomation and ndef.luaautomation.fire_event then
				ndef.luaautomation.fire_event(pos, evtdata)
			else
				atwarn("[atlatc][interrupt] Couldn't run event",evtdata.type,"on",pos,", something wrong with the node",node)
			end
		else
			i=i+1
		end
	end
end



atlatc.interrupt=iq
