--nodedb.lua
--database of all nodes that have 'save_in_at_nodedb' field set to true in node definition


--serialization format:
--(2byte z) (2byte y) (2byte x) (2byte contentid)
--contentid := (14bit nodeid, 2bit param2)

local function int_to_bytes(i)
	local x=i+32768--clip to positive integers
	local cH = math.floor(x /           256) % 256;
	local cL = math.floor(x                ) % 256;
	return(string.char(cH, cL));
end
local function bytes_to_int(bytes)
	local t={string.byte(bytes,1,-1)}
	local n = 
		t[1] *           256 +
		t[2]
    return n-32768
end
local function l2b(x)
	return x%4
end
local function u14b(x)
	return math.floor(x/4)
end
local ndb={}

--local variables for performance
local ndb_nodeids={}
local ndb_nodes={}
local ndb_ver

local function ndbget(x,y,z)
	local ny=ndb_nodes[y]
	if ny then
		local nx=ny[x]
		if nx then
			return nx[z]
		end
	end
	return nil
end
local function ndbset(x,y,z,v)
	if not ndb_nodes[y] then
		ndb_nodes[y]={}
	end
	if not ndb_nodes[y][x] then
		ndb_nodes[y][x]={}
	end
	ndb_nodes[y][x][z]=v
end

-- load/save

local path_pre_v4=minetest.get_worldpath()..DIR_DELIM.."advtrains_ndb2"
--load pre_v4 format
--nodeids get loaded by advtrains init.lua and passed here
function ndb.load_data_pre_v4(data)
	atlog("nodedb: Loading pre v4 format")

	ndb_nodeids = data and data.nodeids or {}
	ndb_ver = data and data.ver or 0
	if ndb_ver < 1 then
		for k,v in pairs(ndb_nodeids) do
			if v == "advtrains:dtrack_xing4590_st" then
				cidDepr = k
			elseif v == "advtrains:dtrack_xing90plusx_45l" then
				cidNew = k
			end
		end
	end
	local file, err = io.open(path_pre_v4, "rb")
	if not file then
		atwarn("Couldn't load the node database: ", err or "Unknown Error")
	else
		-- Note: code duplication because of weird coordinate order in ndb2 format (z,y,x)
		local cnt=0
		local hst_z=file:read(2)
		local hst_y=file:read(2)
		local hst_x=file:read(2)
		local cid=file:read(2)
		while hst_z and hst_y and hst_x and cid and #hst_z==2 and #hst_y==2 and #hst_x==2 and #cid==2 do
			if (ndb_ver < 1 and cid == cidDepr) then
				cid = cidNew
			end
			ndbset(bytes_to_int(hst_x), bytes_to_int(hst_y), bytes_to_int(hst_z), bytes_to_int(cid))
			cnt=cnt+1
			hst_z=file:read(2)
			hst_y=file:read(2)
			hst_x=file:read(2)
			cid=file:read(2)
		end
		atlog("nodedb (ndb2 format): read", cnt, "nodes.")
		file:close()
	end
	ndb_ver = 1
end

-- the new ndb file format is backported from cellworld, and stores the cids also in the ndb file.
-- These functions have the form of a serialize_lib atomic load/save callback and are called from avt_save/avt_load.
function ndb.load_callback(file)
	-- read version
	local vers_byte = file:read(1)
	local version = string.byte(vers_byte)
	if version~=1 then
		file:close()
		error("Doesn't support v4 nodedb file of version "..version)
	end
	
	-- read cid mappings
	local nstr_byte = file:read(2)
	local nstr = bytes_to_int(nstr_byte)
	for i = 1,nstr do
		local stid_byte = file:read(2)
		local stid = bytes_to_int(stid_byte)
		local stna = file:read("*l")
		-- possibly windows fix: strip trailing \r's from line
		stna = string.gsub(stna, "\r$", "")
		--atdebug("content id:", stid, "->", stna)
		ndb_nodeids[stid] = stna
	end
	atlog("[nodedb] read", nstr, "node content ids.")

	-- read nodes
	local cnt=0
	local hst_x=file:read(2)
	local hst_y=file:read(2)
	local hst_z=file:read(2)
	local cid=file:read(2)
	local cidi
	while hst_z and hst_y and hst_x and cid and #hst_z==2 and #hst_y==2 and #hst_x==2 and #cid==2 do
		cidi = bytes_to_int(cid)
		-- prevent file corruption already here
		if not ndb_nodeids[u14b(cidi)] then
			-- clear the ndb data, to reinitialize it
			-- in strict loading mode, doesn't matter as starting will be interrupted anyway
			ndb_nodeids = {}
			ndb_nodes = {}
			error("NDB file is corrupted (found entry with invalid cid)")
		end
		ndbset(bytes_to_int(hst_x), bytes_to_int(hst_y), bytes_to_int(hst_z), cidi)
		cnt=cnt+1
		hst_x=file:read(2)
		hst_y=file:read(2)
		hst_z=file:read(2)
		cid=file:read(2)
	end
	atlog("[nodedb] read", cnt, "nodes.")
	file:close()
end

--save
function ndb.save_callback(data, file)
	--atdebug("storing ndb...")
	-- write version
	file:write(string.char(1))
	
	-- how many cid entries
	local cnt = 0
	for _,_ in pairs(ndb_nodeids) do
		cnt = cnt + 1
	end
	-- write cids
	local nstr = 0
	file:write(int_to_bytes(cnt))
	for stid,stna in pairs(ndb_nodeids) do
		file:write(int_to_bytes(stid))
		file:write(stna)
		file:write("\n")
		nstr = nstr+1
	end
	--atdebug("saved cids count ", nstr)
	
	-- write entries
	local cnt = 0
	for y, ny in pairs(ndb_nodes) do
		for x, nx in pairs(ny) do
			for z, cid in pairs(nx) do
				file:write(int_to_bytes(x))
				file:write(int_to_bytes(y))
				file:write(int_to_bytes(z))
				file:write(int_to_bytes(cid))
				cnt=cnt+1
			end
		end
	end
	--atdebug("saved nodes count ", cnt)
	file:close()
end



--function to get node. track database is not helpful here.
function ndb.get_node_or_nil(pos)
	-- FIX for bug found on linuxworks server:
	-- a loaded node might get read before the LBM has updated its state, resulting in wrongly set signals and switches
	-- -> Using the saved node prioritarily.
	local node = ndb.get_node_raw(pos)
	if node then
		return node
	else
		--try reading the node from the map
		return minetest.get_node_or_nil(pos)
	end
end
function ndb.get_node(pos)
	local n=ndb.get_node_or_nil(pos)
	if not n then
		return {name="ignore", param2=0}
	end
	return n
end
function ndb.get_node_raw(pos)
	local cid=ndbget(pos.x, pos.y, pos.z)
	if cid then
		local nodeid = ndb_nodeids[u14b(cid)]
		if nodeid then
			return {name=nodeid, param2 = l2b(cid)}
		end
	end
	return nil
end


function ndb.swap_node(pos, node, no_inval)
	if advtrains.is_node_loaded(pos) then
		minetest.swap_node(pos, node)
	end
	ndb.update(pos, node)
end

function ndb.update(pos, pnode)
	local node = pnode or minetest.get_node_or_nil(pos)
	if not node or node.name=="ignore" then return end
	if minetest.registered_nodes[node.name] and minetest.registered_nodes[node.name].groups.save_in_at_nodedb then
		local nid
		for tnid, nname in pairs(ndb_nodeids) do
			if nname==node.name then
				nid=tnid
			end
		end
		if not nid then
			nid=#ndb_nodeids+1
			ndb_nodeids[nid]=node.name
		end
		local resid = (nid * 4) + (l2b(node.param2 or 0))
		ndbset(pos.x, pos.y, pos.z, resid )
		--atdebug("nodedb: updating node", pos, "stored nid",nid,"assigned",ndb_nodeids[nid],"resulting cid",resid)
		advtrains.invalidate_all_paths_ahead(pos)
	else
		--at this position there is no longer a node that needs to be tracked.
		--atdebug("nodedb: updating node", pos, "cleared")
		ndbset(pos.x, pos.y, pos.z, nil)
	end
end

function ndb.clear(pos)
	ndbset(pos.x, pos.y, pos.z, nil)
end


--get_node with pseudoload. now we only need track data, so we can use the trackdb as second fallback
--nothing new will be saved inside the trackdb.
--returns:
--true, conn1, conn2, rely1, rely2, railheight   in case everything's right.
--false  if it's not a rail or the train does not drive on this rail, but it is loaded or
--nil    if the node is neither loaded nor in trackdb
--the distraction between false and nil will be needed only in special cases.(train initpos)
function advtrains.get_rail_info_at(pos, drives_on)
	local rdp=advtrains.round_vector_floor_y(pos)
	
	local node=ndb.get_node_or_nil(rdp)
	if not node then return end
	
	local nodename=node.name
	if(not advtrains.is_track_and_drives_on(nodename, drives_on)) then
		return false
	end
	local conns, railheight, tracktype=advtrains.get_track_connections(node.name, node.param2)
	
	return true, conns, railheight
end

local IGNORE_WORLD = advtrains.IGNORE_WORLD

ndb.run_lbm = function(pos, node)
		local cid=ndbget(pos.x, pos.y, pos.z)
		if cid then
			--if in database, detect changes and apply.
			local nodeid = ndb_nodeids[u14b(cid)]
			local param2 = l2b(cid)
			if not nodeid then
				--something went wrong
				atwarn("Node Database corruption, couldn't determine node to set at", pos)
				ndb.update(pos, node)
			else
				if (nodeid~=node.name or param2~=node.param2) then
					--atprint("nodedb: lbm replaced", pos, "with nodeid", nodeid, "param2", param2, "cid is", cid)
					local newnode = {name=nodeid, param2 = param2}
					minetest.swap_node(pos, newnode)
					local ndef=minetest.registered_nodes[nodeid]
					if ndef and ndef.advtrains and ndef.advtrains.on_updated_from_nodedb then
						ndef.advtrains.on_updated_from_nodedb(pos, newnode, node)
					end
					return true
				end
			end
		else
			--if not in database, take it.
			--atlog("Node Database:", pos, "was not found in the database, have you used worldedit?")
			ndb.update(pos, node)
		end
		return false
end


minetest.register_lbm({
        name = "advtrains:nodedb_on_load_update",
        nodenames = {"group:save_in_at_nodedb"},
        run_at_every_load = true,
        run_on_every_load = true,
        action = ndb.run_lbm,
        interval=30,
        chance=1,
    })

--used when restoring stuff after a crash
ndb.restore_all = function()
	--atlog("Updating the map from the nodedb, this may take a while")
	local t1 = os.clock()
	local cnt=0
	local dcnt=0
	for y, ny in pairs(ndb_nodes) do
		for x, nx in pairs(ny) do
			for z, _ in pairs(nx) do
				local pos={x=x, y=y, z=z}
				local node=minetest.get_node_or_nil(pos)
				if node then
					local ori_ndef=minetest.registered_nodes[node.name]
					local ndbnode=ndb.get_node_raw(pos)
					if (ori_ndef and ori_ndef.groups.save_in_at_nodedb) or IGNORE_WORLD then --check if this node has been worldedited, and don't replace then
						if (ndbnode.name~=node.name or ndbnode.param2~=node.param2) then
							minetest.swap_node(pos, ndbnode)
							--atlog("Replaced",node.name,"@",pos,"with",ndbnode.name)
							cnt=cnt+1
						end
					else
						ndb.clear(pos)
						dcnt=dcnt+1
						--atlog("Found ghost node (former",ndbnode and ndbnode.name,") @",pos,"deleting")
					end
				end
			end
		end
	end
	local text="Restore node database: Replaced "..cnt.." nodes, removed "..dcnt.." ghost nodes. (took "..math.floor((os.clock()-t1) * 1000).."ms)"
	atlog(text)
	return text
end
    
minetest.register_on_dignode(function(pos, oldnode, digger)
		ndb.clear(pos)
end)

function ndb.get_nodes()
	return ndb_nodes
end
function ndb.get_nodeids()
	return ndb_nodeids
end


advtrains.ndb=ndb

local ptime=0

minetest.register_chatcommand("at_sync_ndb",
	{
        params = "", -- Short parameter description
        description = "Write node db back to map and find ghost nodes", -- Full description
        privs = {train_operator=true}, 
        func = function(name, param)
				if os.time() < ptime+30 and not minetest.get_player_privs(name, "server") then
					return false, "Please wait at least 30s from the previous execution of /at_restore_ndb!"
				end
				local text = ndb.restore_all()
				ptime=os.time()
				return true, text
        end,
    })

