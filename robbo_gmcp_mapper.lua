local zones = {}
local areas = {}
local exits = {}
local exitDirIndex = {} -- roomUID -> dir -> exit (for O(1) lookup)
local rooms = {}
local roomnotes = {}
local areanotes = {}
local initialized = false
local defaultPortal = nil
local GQinProgress = false -- Global Quest in progress
local gowhereRoomIDs = {}
local gowhereRoomSet = {} -- uid -> true (for O(1) membership checks)
local cbor = require "aardrune/cbor"
local mapperdbpath = rune.config_dir.."/aardrune/data/gmcpmapper_serialized.dat"
local mapperBackupCount = 2
local mapperDataValid = true
local pendingSW = {} -- Store speedwalks that need to wait to arrive at a room before executing
local lastroom = ""
local lastzone = ""
local newexitSource = nil
local newexitCommand = nil
local newexitType = nil
local mapperPathProfile
local nextExitID = nil -- Cached next exit ID to avoid scanning all exits

rune.hooks.on("disconnecting", function()
   -- Save mapper data on disconnect
   saveMapperData()
end)

local function mapperBackupPath(index)
    return mapperdbpath .. ".bak" .. tostring(index)
end

local function mapperIsValidData(data)
    return type(data) == "table"
       and type(data.areas) == "table"
       and type(data.rooms) == "table"
       and type(data.exits) == "table"
       and type(data.areanotes) == "table"
       and type(data.roomnotes) == "table"
end

local function mapperWarnInvalidLoad(reason)
    rune.echo(acs("@RWarning: mapper data file is invalid; attempting backup restore. " .. tostring(reason) .. "@w"))
end

local function mapperLoadSerializedFile(path)
    local file = io.open(path, "rb")
    if not file then return nil, "missing file" end
    local serialized = file:read("*all")
    file:close()
    if not serialized or #serialized == 0 then
        return nil, "empty file"
    end
    local success, data = pcall(function()
        return cbor.decode(serialized)
    end)
    if not success then
        return nil, tostring(data)
    end
    if not mapperIsValidData(data) then
        return nil, "unexpected data format"
    end
    return data, nil
end

local function mapperShiftBackups()
    for i = mapperBackupCount, 1, -1 do
        local src = (i == 1) and mapperdbpath or mapperBackupPath(i - 1)
        local dst = mapperBackupPath(i)
        local file = io.open(src, "rb")
        if file then
            local serialized = file:read("*all")
            file:close()
            local out = io.open(dst, "wb")
            if out then
                out:write(serialized)
                out:close()
            end
        end
    end
end

rune.gmcp.on("room.info",function(data)
   if room == nil then room = {} end
   room["info"] = data

   local roomUID = tostring(room.info.num)
   if lastroom ~= roomUID then
      lastroom = roomUID
      -- TBD
      updateNotesWindow()
   end
   local roomname = data.name
   local roomarea = data.zone
   local roomexits = data.exits
   --rune.dbg("Exits data type"..type(room.info.exits))
   --local roomexits = stringToTable(room.info.exits)
   --local coordinates = room.info.coordinates
    updateRoomGMCP(roomUID,roomname,roomarea,roomexits)
    if gowhereRoomSet[roomUID] then
        gowhereRoomIDs = arrayRemoveEntry(gowhereRoomIDs, roomUID)
        gowhereRoomSet[roomUID] = nil
    end
        
   if pendingSW[roomUID] then
      -- Execute the pending speedwalk for this room
      local speedwalk = pendingSW[roomUID]
      pendingSW[roomUID] = nil -- Clear the pending speedwalk
      rune.echo("Executing pending speedwalk for room " .. roomUID .. ": " .. speedwalk)
      rune.send(speedwalk)
   end
end)

rune.gmcp.on("comm.repop", function(data)
   local zone = data.zone
   local areaName = areas[zone] and areas[zone].name or "Unknown"
   rune.echo(acs("@CRepop for zone @W"..areaName.."@w"))
end)

-- Attach destination room metadata to directive exits so constructSpeedwalk can
-- schedule pendwalk for the correct room (the exit destination).
local function annotateDirectiveExit(dir, touid)
    if type(dir) ~= "string" then return dir end
    local d = dir:lower()
    if d:find("stop", 1, true) or d:find("pendstop", 1, true) then
        return dir .. " @@TOUID:" .. tostring(touid)
    end
    return dir
end

local function peelDirectiveTargetUID(dir)
    if type(dir) ~= "string" then return dir, nil end
    local base, uid = dir:match("^(.-)%s+@@TOUID:(%d+)%s*$")
    if base and uid then
        return base, uid
    end
    return dir, nil
end

local function formatDirectiveDestination(uid)
    local id = uid
    if not id then return tostring(uid), "Unknown room" end
    local name = (rooms and rooms[tostring(id)] and rooms[tostring(id)].name) or
                 (rooms and rooms[id] and rooms[id].name) or
                 "Unknown room"
    return tostring(id), name
end

function aliasMapperDirectiveNotice(name, line, wildcards)
    local destUID = wildcards[1]
    if not destUID then return end
    -- Delay slightly so room text from the MUD is printed first.
    rune.timer.after(0.2, function()
       rune.send(showMapperDirectiveNotice(destUID))
    end)
end

function showMapperDirectiveNotice(destUID)
    local idStr, roomName = formatDirectiveDestination(destUID)
    ColourNote("yellow", "black", string.format("Mapper Directive: Navigate to room %s (%s)", idStr, roomName))
end

function initializeMapper()
    if initialized then return end
    if char.status.state == nil then
       rune.timer.after(1,function()
          initializeMapper()
       end)
       return
    end
    rune.dbg("Robbo_GMCP_Mapper: Initializing GMCP mapper plugin.")
    loadMapperData()
  
    -- Create the notes window if it doesn't exist
    -- TBD: Not sure what to do with notes
    --createNotesWindow()
    
    -- set a timer to save map data
    rune.timer.every(600, function()
        saveMapperData()
    end)

    lastroom = tostring(room.info.num)
    lastzone = room.info.zone
    -- Restore persisted pathfinding profile setting
    mapperPathProfile = true

    -- Set the initial state of the notes window
    initialized = true
end

function aliasMapperHelp(name, line, wildcards)
    local topic = wildcards[1] and wildcards[1]:lower():gsub("^%s+",""):gsub("%s+$","") or ""
    if topic == "exits" or topic == "portals" then
        aliasMapperHelpExits()
        return
    end

    helpHeader("Mapper Commands")
    helpRule()

    helpSection("Rooms")
    helpCmd("ri [id]",                  "Show info for current room (or room by id)")
    helpCmd("mapper roominfo [id]",     "(long form)")
    helpCmd("mapper thisroom [id]",     "(long form)")
    helpCmd("mapper find <query>",      "Search for rooms by name")
    helpCmd("rfind <query>",            "(short form)")
    helpCmd("mapper rooms",             "List all rooms in the current zone, sorted by room ID")
    helpCmd("mapper room <id> delete",  "Delete room and all exits to/from that room")
    helpCmd("roomnote <text>",          "Add/update a note on the current room")
    ColourNote("","","")

    helpSection("Navigation")
    helpCmd("mapper goto <id/name>",    "Speedwalk to a room by ID or name")
    helpCmd("sw <id/name>",             "(short form)")
    helpCmd("mapper findpath <id1> <id2>", "Find path between two room IDs")
    helpCmd("pendwalk <id> <path>",     "Add a pending speedwalk for a room id")
    helpCmd("gowhere",                  "Show current speedwalk destination")
    ColourNote("","","")

    helpSection("Areas")
    helpCmd("mapper areas [filter]",    "List all known areas (optional name filter)")
    helpCmd("mapper area goto <name>",  "Speedwalk to an area's entry room")
    helpCmd("arun <name>",              "(short form)")
    helpCmd("mapper update area <id> <field> <value>", "Update a field on an area record")
    helpCmd("mapper refreshareas",      "Re-sync area list from GMCP")
    helpCmd("updateareas",              "(short form)")
    helpCmd("areanote <text>",          "Add/update a note on the current area")
    ColourNote("","","")

    helpSection("Exits & Portals")
    ColourNote("silver", "black", "  (see: mapper help exits)")
    ColourNote("","","")

    helpSection("Other")
    helpCmd("mapper save",              "Force save mapper data to disk")
    helpCmd("mapper gqstate",           "Show GQ flag state and portal eligibility diagnostics")
    helpRule()
end

function aliasMapperHelpExits(name, line, wildcards)
    helpHeader("Mapper — Exits & Portals")
    helpRule()

    helpSection("Viewing")
    helpCmd("mapper exits",             "List all recorded exits from current room")
    helpCmd("mapper portals",           "List all recorded portals from current room")
    helpCmd("ei [id]",                  "Show exit info for current room (or room id)")
    helpCmd("mapper exitinfo [id]",     "(long form)")
    helpCmd("pi [id]",                  "Show portal info for current room (or room id)")
    helpCmd("mapper portalinfo [id]",   "(long form)")
    ColourNote("","","")

    helpSection("Editing")
    helpCmd("mapper exit <id> <field> <value>",   "Update a field on an exit <id>")
    helpCmd("mapper exit <id> delete",            "Delete exit with <id>")
    helpCmd("mapper portal <id> <field> <value>", "Update a field on a portal from room <id>")
    helpCmd("mapper cexit <command>",                "Create a custom exit from the current room. Wait 2 seconds after executing.")
    helpCmd("mapper createportal <command>",         "Create a portal exit to the current room")
    ColourNote("","","")
    
    helpSection("Exit Directives (for intermediate steps)")
    helpCmd("stop",                                 "Halt pathfinding; execute commands in this exit, don't continue beyond")
    helpCmd("pendstop",                             "Queue remaining path via pendwalk on arrival; execute commands now")
    ColourNote("","","")
    
    helpSection("Directive Examples")
    ColourNote("silver", "black", "stop directive (in exit dir field):")
    ColourNote("silver", "black", "  huntalias mobname;stop")
    ColourNote("silver", "black", "  → Executes 'huntalias mobname' at source room, path halts there")
    ColourNote("silver", "black", "")
    ColourNote("silver", "black", "pendstop directive (in exit dir field):")
    ColourNote("silver", "black", "  huntalias mobname;pendstop")
    ColourNote("silver", "black", "  → Executes 'huntalias mobname' at source room (to find target)")
    ColourNote("silver", "black", "       then queues remaining path via pendwalk when target room is reached")
    helpRule()
end

local function hasFlag(flagsStr, flag)
    if not flagsStr then return false end
    for token in tostring(flagsStr):gmatch("[^,%s]+") do
        if token:lower() == flag then return true end
    end
    return false
end

-- Generate a unique exit ID by finding the maximum existing ID and incrementing
-- Uses a cache to avoid scanning all exits on every call
function generateExitID()
    if nextExitID == nil then
        -- First use: scan once to find the current max
        local maxID = 0
        for roomUID, exitList in pairs(exits) do
            if type(exitList) == "table" then
                for _, exit in ipairs(exitList) do
                    if exit.id and tonumber(exit.id) then
                        local id = tonumber(exit.id)
                        if id > maxID then
                            maxID = id
                        end
                    end
                end
            end
        end
        nextExitID = maxID + 1
    end
    local id = nextExitID
    nextExitID = nextExitID + 1
    return id
end

function addPendingSpeedwalk(name, line, wildcards)
    local roomUID = wildcards[1]
    local speedwalk = wildcards[2]
    -- Add a speedwalk to be executed when the player arrives at the specified room
    if not pendingSW[roomUID] then
        pendingSW[roomUID] = speedwalk
    else
        rune.echo("Speedwalk already pending for room " .. roomUID .. ". Overwriting.")
        pendingSW[roomUID] = speedwalk
    end
end

function setPendingSpeedwalk(roomUID, speedwalk)
    pendingSW[tostring(roomUID)] = speedwalk
end

function queueGowhereRooms(roomUIDs)
    gowhereRoomIDs = {}
    gowhereRoomSet = {}
    for _, uid in ipairs(roomUIDs) do
        local uidStr = tostring(uid)
        if uidStr ~= tostring(room.info.num) then
            table.insert(gowhereRoomIDs, uidStr)
            gowhereRoomSet[uidStr] = true
        end
    end
end

function roomsInZone(zone)
    -- Returns a list of room UIDs in the specified zone
    local roomList = {}
    for uid, room in pairs(rooms) do
        if room.area == zone then
            table.insert(roomList, uid)
        end
    end
    return table.concat(roomList,'|')
end

function getRoomExits(roomUID)
    -- Returns a pipe-separated string of exit directions for a room
    -- Order: n, s, e, w, u, d, then custom directions
    if not roomUID or not exits[roomUID] then return "" end
    local priority = { n = 1, s = 2, e = 3, w = 4, u = 5, d = 6 }
    local standard = {}
    local custom = {}
    for _, exit in ipairs(exits[roomUID]) do
        if exit.dir then
            local dir = exit.dir
            local dirLower = dir:lower()
            if priority[dirLower] then
                standard[priority[dirLower]] = dir
            else
                table.insert(custom, dir)
            end
        end
    end
    local result = {}
    for i = 1, 6 do
        if standard[i] then table.insert(result, standard[i]) end
    end
    for _, dir in ipairs(custom) do
        table.insert(result, dir)
    end
    return table.concat(result, "|")
end


-- Helper function to estimate distance between rooms (heuristic for A*)
function estimateDistance(roomUID1, roomUID2)
    -- A simple heuristic: if rooms are in the same area, distance is 1, otherwise it's 2
    -- You could implement a more sophisticated heuristic based on room coordinates if available
    if rooms[roomUID1] and rooms[roomUID2] and rooms[roomUID1].area == rooms[roomUID2].area then
        return 1
    else
        return 2
    end
end

-- Helper function to reconstruct the path from the cameFrom map
function reconstructPath(cameFrom, directionTaken, current)
    local totalPath = {}
    
    while cameFrom[current] do
        table.insert(totalPath, 1, directionTaken[current])
        current = cameFrom[current]
    end
    
    return totalPath
end

-- Add a function to get all handheld portal exits the player can actually use
-- at their current effective level. Entries with no level (or level <= playerLevel)
-- are included; higher-level-requirement portals are filtered out.
function getHandheldPortalExits(playerLevel)
    local portalExits = {}
    -- Look for exits with source '*' which indicates a handheld portal / shortcut
    for rnum, exitList in pairs(exits) do
        if rnum == '*' then
            for _, exit in ipairs(exitList) do
                local reqLevel = tonumber(exit.level) or 0
                if reqLevel <= (playerLevel or 0) then
                    table.insert(portalExits, exit)
                end
            end
        end
    end
    return portalExits
end

function aliasExitSearch(name,line,wildcards)
    -- List any exits that the dir contains the search string
    local searchstr = wildcards[2]:lower()
    local matchfound = false
    for rnum, exitList in pairs(exits) do
        for _, exit in ipairs(exitList) do
            if exit.dir and exit.dir:lower():find(searchstr) then
                rune.echo("Exit from room " .. rnum .. " with command '" .. exit.dir .. "' matches search string '" .. searchstr .. "'. ID: " .. exit.id)
            end
        end
    end
    if not matchfound then
        rune.echo("No exits found with door commands matching '" .. searchstr .. "'.")
    end
end

-- Create a generic pathfinding function that accepts a goal validator
function findPathGeneric(startUID, isGoalFunc, getHeuristicFunc, playerLevel)
    -- Check if start room exists
    if not rooms[startUID] then
        return nil, nil, "Starting room " .. startUID .. " does not exist"
    end

    -- ------------------------------------------------------------------
    -- High-resolution timer + profiling
    -- ------------------------------------------------------------------
    local function nowSec()
        if utils and utils.timer then return utils.timer() end
        return os.clock()
    end
    local profileEnabled = (mapperPathProfile == true) or (rune.store.get("mapper_profile") == "1")
    local tStart = nowSec()

    -- ------------------------------------------------------------------
    -- A* tunables / safety limits
    -- ------------------------------------------------------------------
    -- Portal hop limits are tracked separately:
    --   - handheld portals ('portal' flag) are bulky and rarely chained
    --   - recall mechanics ('recall' flag, e.g. home/recall commands) may
    --     legitimately precede a handheld portal in a single trip.
    -- Typical real path: one recall + one handheld portal.
    local MAX_PORTAL_HOPS = 1          -- max chained handheld-portal-flagged hops
    local MAX_RECALL_HOPS = 1          -- max chained recall-flagged hops
    local MAX_ITERATIONS  = 50000      -- bail after this many node expansions
    local MAX_SECONDS     = 5.0        -- bail after this much wall-clock time

    -- ------------------------------------------------------------------
    -- Data structures
    -- ------------------------------------------------------------------
    local closedSet = {}      -- Rooms already evaluated  (uid -> true)
    local gScore = {}         -- Cost from start to current node
    local fScore = {}         -- Estimated total cost from start to goal through current node
    local cameFrom = {}       -- Path reconstruction map
    local directionTaken = {} -- Direction taken to reach each room
    local doorCommands = {}   -- Additional door commands needed before moving
    local portalHops = {}     -- # of portal-flagged hops used to reach each room
    local recallHops = {}     -- # of recall-flagged hops used to reach each room

    -- Binary min-heap keyed by fScore[uid]. Stores room UIDs.
    -- This replaces the previous O(n) linear scan with O(log n) extract-min / insert.
    local openHeap = {}
    local openMembership = {} -- uid -> true if currently in heap (O(1) membership test)

    local function heapPush(uid)
        openHeap[#openHeap + 1] = uid
        openMembership[uid] = true
        local i = #openHeap
        while i > 1 do
            local parent = math.floor(i / 2)
            if (fScore[openHeap[parent]] or math.huge) > (fScore[openHeap[i]] or math.huge) then
                openHeap[i], openHeap[parent] = openHeap[parent], openHeap[i]
                i = parent
            else
                break
            end
        end
    end

    local function heapPop()
        local n = #openHeap
        if n == 0 then return nil end
        local top = openHeap[1]
        openMembership[top] = nil
        if n == 1 then
            openHeap[1] = nil
            return top
        end
        openHeap[1] = openHeap[n]
        openHeap[n] = nil
        n = n - 1
        local i = 1
        while true do
            local l, r = i * 2, i * 2 + 1
            local smallest = i
            if l <= n and (fScore[openHeap[l]] or math.huge) < (fScore[openHeap[smallest]] or math.huge) then
                smallest = l
            end
            if r <= n and (fScore[openHeap[r]] or math.huge) < (fScore[openHeap[smallest]] or math.huge) then
                smallest = r
            end
            if smallest ~= i then
                openHeap[i], openHeap[smallest] = openHeap[smallest], openHeap[i]
                i = smallest
            else
                break
            end
        end
        return top
    end

    -- When a node's fScore is *improved* while still in the heap, push it again.
    -- The stale entry will be skipped via the closedSet/duplicate-check when popped.
    local function heapDecrease(uid)
        -- Simplest correct approach: re-push. The older copy will be ignored on pop.
        openHeap[#openHeap + 1] = uid
        local i = #openHeap
        while i > 1 do
            local parent = math.floor(i / 2)
            if (fScore[openHeap[parent]] or math.huge) > (fScore[openHeap[i]] or math.huge) then
                openHeap[i], openHeap[parent] = openHeap[parent], openHeap[i]
                i = parent
            else
                break
            end
        end
    end

    -- Get handheld portal exits that the player can use
    local portalExits = getHandheldPortalExits(playerLevel)

    -- ------------------------------------------------------------------
    -- Precompute portal candidate lists keyed by room state.
    --
    -- The set of usable portal/recall entries from a given room depends only on:
    --   - whether the room is noportal
    --   - whether the room is norecall
    -- ...plus the global nogq/level flags which are constant for this search.
    --
    -- We index by a state key built from (noportal, norecall) booleans.
    -- Each entry is a flat list of portal exits already filtered + ordered
    -- (defaultPortal last, like the per-iteration code used to produce).
    -- This converts per-node O(P) filtering into a single hash lookup.
    -- ------------------------------------------------------------------
    local function buildPortalsForState(inNoPortalRoom, inNoRecallRoom)
        -- Helper: classify the hop "kind" for a portal exit.
        -- An entry can carry both flags in theory; portal-flagged takes precedence
        -- for hop-budget purposes since it represents the more constrained resource.
        local function classify(p)
            if hasFlag(p.flags, "portal") then return "portal" end
            if hasFlag(p.flags, "recall") then return "recall" end
            return "none"
        end

        local defaultPortal = nil
        local usable = {}
        for _, portalExit in ipairs(portalExits) do
            local isPortalFlagged = hasFlag(portalExit.flags, "portal")
            local isRecallFlagged = hasFlag(portalExit.flags, "recall")

            local skip = false
            if (tonumber(portalExit.level) or 0) > (playerLevel or 0) then skip = true end
            if hasFlag(portalExit.flags, "nogq") and GQinProgress then skip = true end
            if isPortalFlagged and inNoPortalRoom then skip = true end
            if isRecallFlagged and inNoRecallRoom then skip = true end

            if not skip then
                if hasFlag(portalExit.flags, "default") then
                    defaultPortal = portalExit
                else
                    table.insert(usable, portalExit)
                end
            end
        end

        local result = {}
        local function push(p)
            table.insert(result, { exit = p, kind = classify(p) })
        end

        if inNoRecallRoom then
            -- HARD RULE: from a norecall room, the only portal-flagged entry that may
            -- be used is the default portal. Non-portal-flagged shortcuts (e.g. plain
            -- recall/home commands without the portal flag) are still allowed.
            for _, p in ipairs(usable) do
                if not hasFlag(p.flags, "portal") then
                    push(p)
                end
            end
            if defaultPortal then
                push(defaultPortal)
            end
        else
            for _, p in ipairs(usable) do
                push(p)
            end
            if defaultPortal then
                push(defaultPortal)
            end
        end
        return result
    end

    -- Four possible room states; build all up front (only 4 calls of O(P) work).
    local portalsByState = {
        [1] = buildPortalsForState(false, false), -- normal room
        [2] = buildPortalsForState(true,  false), -- noportal
        [3] = buildPortalsForState(false, true),  -- norecall
        [4] = buildPortalsForState(true,  true),  -- noportal + norecall
    }
    local function portalStateKey(room)
        local np = (room.noportal == 1)
        local nr = (room.norecall == 1)
        if np and nr then return 4
        elseif nr then return 3
        elseif np then return 2
        else return 1 end
    end

    -- Initialize with starting room
    gScore[startUID] = 0
    fScore[startUID] = getHeuristicFunc(startUID)
    portalHops[startUID] = 0
    recallHops[startUID] = 0
    heapPush(startUID)

    -- Profiling counters
    local iterations      = 0
    local exitChecks      = 0
    local portalChecks    = 0
    local nodesExpanded   = 0
    local bailReason      = nil

    -- Helper function to check if an exit is valid based on flags
    local function isValidExit(exit, currentRoom)
        -- Check if the room exists
        if not rooms[currentRoom] then
            return false
        end
        
        -- Check level requirement
        if tonumber(exit.level) > playerLevel then
            return false
        end

        -- Skip exits with disabled flag
        if hasFlag(exit.flags, "disabled") then
            return false
        end
        
        -- Skip exits with nogq flag during global quests
        if hasFlag(exit.flags, "nogq") and GQinProgress then
            return false
        end
        
        -- Skip portal exits in noportal rooms
        if hasFlag(exit.flags, "portal") and rooms[currentRoom].noportal == 1 then
            return false
        end
        
        -- Skip recall exits in norecall rooms
        if hasFlag(exit.flags, "recall") and rooms[currentRoom].norecall == 1 then
            return false
        end
        
        -- Check if the destination room exists
        if not rooms[exit.touid] then
            return false
        end
        
        return true
    end

    local function emitProfile(result, current)
        if not profileEnabled then return end
        local elapsed = nowSec() - tStart
        rune.echo(string.format(
            "[pathprof] result=%s iters=%d expanded=%d exitChks=%d portChks=%d openHeap=%d time=%.3fs%s",
            tostring(result), iterations, nodesExpanded, exitChecks, portalChecks,
            #openHeap, elapsed,
            bailReason and (" bail=" .. bailReason) or ""
        ))
    end

    while #openHeap > 0 do
        iterations = iterations + 1
        if iterations > MAX_ITERATIONS then
            bailReason = "max_iterations"
            emitProfile("aborted", nil)
            return nil, nil, "Pathfinding aborted: exceeded " .. MAX_ITERATIONS .. " iterations"
        end
        -- Cheap to check os.clock once per iteration
        if (iterations % 64) == 0 then
            if (nowSec() - tStart) > MAX_SECONDS then
                bailReason = "max_seconds"
                emitProfile("aborted", nil)
                return nil, nil, string.format("Pathfinding aborted: exceeded %.1fs", MAX_SECONDS)
            end
        end

        -- Pop the lowest-fScore node from the heap. Skip stale duplicates.
        local current = heapPop()
        if current == nil then break end
        if closedSet[current] then
            -- stale heap entry from a previous heapDecrease push; skip
            -- (loop continues)
        else
            nodesExpanded = nodesExpanded + 1

            -- If we've reached a goal, reconstruct and return the path
            if isGoalFunc(current) then
                local path = reconstructPathWithDoors(cameFrom, directionTaken, doorCommands, current)
                emitProfile("found", current)
                return current, path, nil
            end

            closedSet[current] = true

            -- Process each neighbor (exit) of the current room
            if exits[current] then
                for _, exit in ipairs(exits[current]) do
                    exitChecks = exitChecks + 1
                    if isValidExit(exit, current) then
                        local neighbor = exit.touid

                        if not closedSet[neighbor] then
                            local tentative_gScore = gScore[current] + 1
                            if exit.flags and exit.flags:find("door") then
                                tentative_gScore = tentative_gScore + 0.1
                            end

                            if not gScore[neighbor] or tentative_gScore < gScore[neighbor] then
                                cameFrom[neighbor] = current
                                directionTaken[neighbor] = annotateDirectiveExit(exit.dir, neighbor)

                                if exit.flags and exit.flags:find("door") then
                                    if exit.doorcommand then
                                        doorCommands[neighbor] = exit.doorcommand
                                    else
                                        doorCommands[neighbor] = "open " .. exit.dir
                                    end
                                else
                                    doorCommands[neighbor] = nil
                                end

                                gScore[neighbor] = tentative_gScore
                                fScore[neighbor] = gScore[neighbor] + getHeuristicFunc(neighbor)
                                portalHops[neighbor] = portalHops[current] or 0
                                recallHops[neighbor] = recallHops[current] or 0

                                if openMembership[neighbor] then
                                    heapDecrease(neighbor)
                                else
                                    heapPush(neighbor)
                                end
                            end
                        end
                    end
                end
            end

            -- Portal / recall / home shortcuts. See notes above for flag rules.
            -- Hop budgets are tracked separately per kind so a recall-flagged
            -- shortcut and a handheld portal can be chained in the same path.
            if rooms[current] then
                local curPortalHops = portalHops[current] or 0
                local curRecallHops = recallHops[current] or 0
                local canPortal = curPortalHops < MAX_PORTAL_HOPS
                local canRecall = curRecallHops < MAX_RECALL_HOPS

                -- If neither budget remaining, skip injection entirely.
                if canPortal or canRecall then
                    local portalsToConsider = portalsByState[portalStateKey(rooms[current])]

                    for _, entry in ipairs(portalsToConsider) do
                        portalChecks = portalChecks + 1
                        local portalExit = entry.exit
                        local kind = entry.kind  -- "portal" | "recall" | "none"

                        -- Per-entry budget gate
                        local allowed
                        if kind == "portal" then
                            allowed = canPortal
                        elseif kind == "recall" then
                            allowed = canRecall
                        else
                            -- Entries with neither flag (rare) are unconstrained;
                            -- charge against the portal budget to keep them bounded.
                            allowed = canPortal
                        end

                        if allowed then
                            local neighbor = portalExit.touid
                            if not closedSet[neighbor] and rooms[neighbor] then
                                local tentative_gScore = gScore[current] + 1.5
                                if not gScore[neighbor] or tentative_gScore < gScore[neighbor] then
                                    cameFrom[neighbor] = current
                                    directionTaken[neighbor] = annotateDirectiveExit(portalExit.dir, neighbor)
                                    doorCommands[neighbor] = nil

                                    gScore[neighbor] = tentative_gScore
                                    fScore[neighbor] = gScore[neighbor] + getHeuristicFunc(neighbor)

                                    -- Increment the appropriate hop counter
                                    if kind == "recall" then
                                        portalHops[neighbor] = curPortalHops
                                        recallHops[neighbor] = curRecallHops + 1
                                    else
                                        portalHops[neighbor] = curPortalHops + 1
                                        recallHops[neighbor] = curRecallHops
                                    end

                                    if openMembership[neighbor] then
                                        heapDecrease(neighbor)
                                    else
                                        heapPush(neighbor)
                                    end
                                end
                            end
                        end
                    end
                end
            else
                rune.dbg("Warning: Room " .. current .. " referenced in path but not found in rooms table")
            end
        end
    end

    -- If we get here, no path was found
    emitProfile("no_path", nil)
    return nil, nil, "No path found from " .. startUID
end

-- Now replace findPath with a version that uses findPathGeneric
function findPath(startUID, destUID, playerLevel)
    -- Validate destination room
    if not rooms[destUID] then
        return nil, "Destination room " .. destUID .. " does not exist"
    end

    rune.dbg("Mapper: Finding path from room "..tostring(startUID).." to "..tostring(destUID).." player level is "..tostring(playerLevel))
    -- Create the goal function to check if we've reached the destination
    local function isGoalFunc(roomUID)
        return roomUID == destUID
    end
    
    -- Create the heuristic function for A*
    local function getHeuristicFunc(roomUID)
        return estimateDistance(roomUID, destUID)
    end
    
    -- Call the generic pathfinding function
    local _, path, error = findPathGeneric(startUID, isGoalFunc, getHeuristicFunc, playerLevel)
    
    return path, error
end

-- Find a path from startUID to whichever of destUIDs is reachable / closest.
-- Returns: matchedUID, path, error
function findPathToAny(startUID, destUIDs, playerLevel)
    if not destUIDs or #destUIDs == 0 then
        return nil, nil, "No destination candidates provided"
    end

    -- Build a lookup set of valid destinations (existing rooms only)
    local destSet = {}
    local validDests = {}
    for _, uid in ipairs(destUIDs) do
        if rooms[uid] then
            destSet[uid] = true
            table.insert(validDests, uid)
        end
    end
    if #validDests == 0 then
        return nil, nil, "None of the candidate destinations exist in the map"
    end

    -- Goal: any room in destSet
    local function isGoalFunc(roomUID)
        return destSet[roomUID] == true
    end

    -- Heuristic: minimum estimated distance to any candidate (admissible
    -- since real distance to the chosen goal is >= min over all goals)
    local function getHeuristicFunc(roomUID)
        local best = math.huge
        for _, dUID in ipairs(validDests) do
            local d = estimateDistance(roomUID, dUID)
            if d and d < best then best = d end
        end
        if best == math.huge then return 0 end
        return best
    end

    local matched, path, err = findPathGeneric(startUID, isGoalFunc, getHeuristicFunc, playerLevel)
    return matched, path, err
end

-- Replace findNearestInArea with a version that uses findPathGeneric
function findNearestInArea(startUID, destArea, playerLevel)
    -- Check if destination area exists and has rooms
    local areaRooms = {}
    for uid, room in pairs(rooms) do
        if room.area == destArea then
            table.insert(areaRooms, tostring(uid))
        end
    end
    
    if #areaRooms == 0 then
        return nil, nil, "Destination area '" .. destArea .. "' does not exist or has no rooms"
    end
    
    -- Create the goal function to check if we've reached any room in the target area
    local function isGoalFunc(roomUID)
        return rooms[roomUID] and rooms[roomUID].area == destArea
    end
    
    -- Create the heuristic function for A*
    local function getHeuristicFunc(roomUID)
        -- Calculate minimum heuristic to any target room
        local minH = math.huge
        for _, targetUID in ipairs(areaRooms) do
            local h = estimateDistance(roomUID, targetUID)
            if h < minH then
                minH = h
            end
        end
        return minH
    end
    
    -- Call the generic pathfinding function
    local targetRoom, path, error = findPathGeneric(startUID, isGoalFunc, getHeuristicFunc, playerLevel)
    rune.dbg("findNearestInArea: Found target room " .. (targetRoom or "nil") .. " with path: " .. (path and table.concat(path, ", ") or "nil"))
    return targetRoom, path, error
end

-- Helper function to reconstruct the path including door commands
-- Fix the reconstructPathWithDoors function to put door commands before movement
function reconstructPathWithDoors(cameFrom, directionTaken, doorCommands, current)
    local totalPath = {}
    
    while cameFrom[current] do
        -- First add movement direction
        table.insert(totalPath, 1, directionTaken[current])
        
        -- Then insert door command before the movement if needed
        -- Door commands should be placed BEFORE the movement, not after
        if doorCommands[current] then
            table.insert(totalPath, 1, doorCommands[current])
        end
        
        current = cameFrom[current]
    end
    
    return totalPath
end


function searchRoomsByName(roomName,area)
    -- Search for rooms by name, with optional area filter
    -- Usage example:
    -- local results = searchRoomsByName("forest", "forestArea")
    local results = {}
    if area == nil or area == "" then
        -- Search all rooms
        for uid, room in pairs(rooms) do
            if room.name:lower():find(roomName:lower()) then
                table.insert(results, {uid = uid, name = room.name, area = room.area})
            end
        end
    else
        -- Search rooms in the specified area
        for uid, room in pairs(rooms) do
            if room.area == area and room.name:lower():find(roomName:lower()) then
                table.insert(results, {uid = uid, name = room.name, area = room.area})
            end
        end
    end

        -- Sort results by area (alphabetically)
    table.sort(results, function(a, b) 
        return (a.area or "Unknown"):lower() < (b.area or "Unknown"):lower() 
    end)
    return results
end

function aliasMapperFindRoom(name, line, wildcards)
    -- Alias to find a room by name
    local roomName = wildcards[2]
    if roomName == "" then
        rune.echo("Please provide a room name to search for.")
        return
    end
    local results = searchRoomsByName(roomName)

        -- Display results as a fixed-width table with header row, up to 30 results
    if #results == 0 then
        rune.echo("No rooms found matching '" .. roomName .. "' in area '" .. (area or "all") .. "'.")
    else
        local header = string.format("%-10s %-55s %-15s", "ID", "Room Name", "Area")
        rune.echo(header)
        rune.echo("---------  ------------------------------------------------------  -------------")
        for _, room in ipairs(results) do
            local uid = room.uid
            if string.find(uid,"nomap") then uid = "nomap" end
            local line = string.format("%-10s %-55s %-15s", uid, room.name, room.area)
            rune.echo(line)
        end
    end
end

function findFirstMatchingRoom(searchstr, area, currentRoomUID)
    -- Find the first room where the name contains the search string (not case-sensitive)
    -- Optionally filter by area
    -- Optionally exclude the current room from results
    -- Usage example:
    -- local room = findFirstMatchingRoom("forest", "forestArea", "12345") -- Exclude room 12345
    
    for uid, room in pairs(rooms) do
        -- Skip the current room if specified
        if uid ~= currentRoomUID then
            if room.name:lower():find(searchstr:lower()) then
                if area == nil or room.area == area then
                    return uid
                end
            end
        end
    end
    return nil -- No matching room found
end

function findAllMatchingRooms(searchstr, area, currentRoomUID)
    -- Return a list of all room UIDs whose name contains searchstr (case-insensitive).
    -- Optionally filter by area, optionally exclude the current room.
    local results = {}
    local needle = searchstr:lower()
    for uid, room in pairs(rooms) do
        if uid ~= currentRoomUID and room.name and room.name:lower():find(needle, 1, true) then
            if area == nil or room.area == area then
                table.insert(results, uid)
            end
        end
    end
    return results
end

function findFirstMatchingArea(searchstr)
    rune.dbg("Searching for first matching area with search string: " .. searchstr or "")
    -- Find the first area where the name contains the search string (not case-sensitive)
    -- It will attempt to match the UID (keyword) first.
    -- Usage example:
    -- local area = findFirstMatchingArea("forest")
    local needle = searchstr:lower()
    for uid, area in pairs(areas) do
        if uid:lower():find(needle, 1, true) then
            return uid
        end
        if area.name and area.name:lower():find(needle, 1, true) then
            return uid
        end
    end
    return nil -- No matching area found
end

function findAreaExact(searchstr)
    -- Return the keyword (UID) of the first area that matches the exact name
    for uid, area in pairs(areas) do
        if area.name == searchstr then
            return uid
        end
    end
    return nil -- No matching area found
end

function findRoomExact(searchstr, area, currentRoomUID, level)
    -- Find a room by exact name match, optionally filtering by area
    -- Usage example:
    -- local room = findRoomExact("forest", "forestArea")
    -- As this is called by an external plugin, we have to return results (a list of roomUIDs) as a pipe-delimited string.
    if currentRoomUID == nil then currentRoomUID = "none" end

    if area and not areas[area] then
        -- We may have been provided a full area name. Only replace `area` if an exact
        -- name match is found; otherwise keep the original value so filtering remains scoped.
        local matchedArea = findAreaExact(area)
        if matchedArea then
            area = matchedArea
        end
    end
    local results = {}
    for uid, room in pairs(rooms) do
        if room.name == searchstr then
            if (area == nil or room.area == area) and room.uid ~= currentRoomUID then
                -- If we have a level, check if the room is accessible at that level
                if level ~= nil then
                    if not areas[room.area].levelMin then areas[room.area].levelMin = 1 end
                    if not areas[room.area].levelMax then areas[room.area].levelMax = 291 end
                    if areas[room.area] and areas[room.area].levelMin < (level+5) and areas[room.area].levelMax > (level-5) then
                        table.insert(results, uid)
                        -- Room is in an area that is too high level for the player
                    end
                else
                    -- No level provided, just return the room UID
                    table.insert(results, uid)
                end
            end
        end
    end
    if #results == 0 then
        return nil -- No matching room found
    else
        return table.concat(results, "|") -- Return as pipe-delimited string
    end
end

function getRoomArea(roomUID)
    -- Get the area of a room by its UID
    if not rooms[roomUID] then
        return nil -- "Room " .. roomUID .. " does not exist"
    end
    return rooms[roomUID].area
end

function constructSpeedwalk(directions)
    if not directions or #directions == 0 then
        return ""
    end

    local function build(dirs)
        local result = {}
        local currentRun = {}
        local basicDirs = {n=true, s=true, e=true, w=true, u=true, d=true}

        for i, rawDir in ipairs(dirs) do
            local dir, directiveTargetUID = peelDirectiveTargetUID(rawDir)

            if basicDirs[dir] then
                table.insert(currentRun, dir)
            else
                if #currentRun > 0 then
                    table.insert(result, optimizeRun(currentRun))
                    currentRun = {}
                end

                local immediate = {}
                local directive = nil -- "stop" | "pendstop" | nil
                for part in tostring(dir):gmatch("[^;]+") do
                    local cmd = part:gsub("^%s+", ""):gsub("%s+$", "")
                    local lower = cmd:lower()
                    if lower == "stop" then
                        directive = "stop"
                        break
                    elseif lower == "pendstop" then
                        directive = "pendstop"
                        break
                    elseif cmd ~= "" then
                        table.insert(immediate, cmd)
                    end
                end

                if #immediate > 0 then
                    table.insert(result, table.concat(immediate, ";"))
                end

                if directive == "pendstop" then
                    if directiveTargetUID then
                        table.insert(result, string.format("mapper _directive_notice %d", directiveTargetUID))
                    end
                    local remaining = {}
                    for j = i + 1, #dirs do
                        table.insert(remaining, dirs[j])
                    end

                    if #remaining > 0 and directiveTargetUID then
                        local remainingSW = build(remaining)
                        if remainingSW ~= "" then
                            -- Queue continuation for the destination room of this directive exit.
                            table.insert(result, string.format("pendwalk %d %s", directiveTargetUID, remainingSW))
                        end
                    end
                    return table.concat(result, ";")
                elseif directive == "stop" then
                    if directiveTargetUID then
                        table.insert(result, string.format("mapper _directive_notice %d", directiveTargetUID))
                    end
                    return table.concat(result, ";")
                end
            end
        end

        if #currentRun > 0 then
            table.insert(result, optimizeRun(currentRun))
        end

        return table.concat(result, ";")
    end

    return build(directions)
end

-- Helper function to optimize a run of basic directions
function optimizeRun(directions)
    if #directions == 0 then
        return ""
    end
    
    -- Compress repeated directions (e.g., "eeeee" becomes "5e")
    local compressed = {}
    local count = 1
    local current = directions[1]
    
    for i = 2, #directions do
        if directions[i] == current then
            count = count + 1
        else
            if count > 1 then
                table.insert(compressed, count .. current)
            else
                table.insert(compressed, current)
            end
            current = directions[i]
            count = 1
        end
    end
    
    -- Add the last direction sequence
    if count > 1 then
        table.insert(compressed, count .. current)
    else
        table.insert(compressed, current)
    end
    
    -- If we have just one direction, return it directly
    if #compressed == 1 and #compressed[1] == 1 then
        return compressed[1]
    end
    
    -- Otherwise, format as a "run" command
    return "run " .. table.concat(compressed, "")
end

-- Example usage:
-- local path = findPath("12345", "67890", 50)
-- if path then
--     local speedwalk = constructSpeedwalk(path)
--     rune.echo("Speedwalk: " .. speedwalk)
--     -- Can now execute with: Send(speedwalk)
-- end

function aliasFindPath(name, line, wildcards)
    -- Alias to find a path between two rooms
    local startUID = wildcards[1]
    local destUID = wildcards[2]
    if not startUID or not destUID then
        rune.echo("Usage: findpath <start room> <destination room>")
        return
    end
    
    local playerLevel = effectiveLevel()
    local path, error = findPath(startUID, destUID, playerLevel)
    
    if path then
        local rawPath = table.concat(path, ", ")
        local speedwalk = constructSpeedwalk(path)
        rune.echo("Raw path: " .. rawPath)
        rune.echo("Speedwalk: " .. speedwalk)
    else
        rune.echo("Error finding path: " .. error)
    end
end

function aliasMapperGoto(name, line, wildcards)
    -- Get the destination search string
    local destSearch = wildcards[2]
    if not destSearch or destSearch == "" then
        rune.echo("Usage: mapper goto <room UID or room name>")
        return
    end
    
    if destSearch:lower() == "unknown" then
        rune.echo("Error: 'unknown' is not a valid room UID or name")
        return
    end

    -- Get current room as source
    local sourceUID = tostring(room.info.num)
    rune.dbg("GMCP Mapper: source room is: "..sourceUID)
    if not sourceUID then
        rune.echo("Error: Could not determine your current location")
        return
    end

    local playerLevel = effectiveLevel()

    -- Numeric search: must match a single existing room UID
    if tonumber(destSearch) then
        if not rooms[destSearch] then
            rune.echo("Error: No room with UID " .. destSearch .. " exists")
            return
        end
        if sourceUID == destSearch then
            rune.echo("You are already in that room!")
            return
        end
        rune.echo("Destination: " .. rooms[tostring(destSearch)].name .. " (" .. destSearch .. ")")
        local path, err = findPath(sourceUID, destSearch, playerLevel)
        if not path then
            rune.echo("Error finding path: " .. err)
            return
        end
        local speedwalk = constructSpeedwalk(path)
        rune.echo("Navigating to destination via: " .. speedwalk)
        rune.send(speedwalk)
        return
    end

    -- Name search: gather all matches and ask A* to reach any of them
    local candidates = findAllMatchingRooms(destSearch, nil, sourceUID)
    if #candidates == 0 then
        rune.echo("Error: Could not find any room matching '" .. destSearch .. "'")
        return
    end

    if #candidates == 1 then
        rune.echo("Found destination room: " .. rooms[candidates[1]].name .. " (" .. candidates[1] .. ")")
    else
        rune.echo("Found " .. #candidates .. " rooms matching '" .. destSearch .. "'; picking the closest reachable one.")
        for _, uid in ipairs(candidates) do
            rune.dbg("  candidate: " .. uid .. " - " .. (rooms[uid].name or "?"))
        end
    end

    local matchedUID, path, err = findPathToAny(sourceUID, candidates, playerLevel)
    if not path then
        rune.echo("Error finding path: " .. (err or "no reachable match"))
        return
    end

    rune.echo("Selected destination: " .. rooms[matchedUID].name .. " (" .. matchedUID .. ")")
    local speedwalk = constructSpeedwalk(path)
    rune.echo("Navigating to destination via: " .. speedwalk)
    rune.send(speedwalk)
end

function aliasMapperAreas(name, line, wildcards)
    -- Display areas in a table format, optionally filtered by wildcards[1]
    local areaFilter = wildcards[1]
    if areaFilter and areaFilter ~= "" then
        areaFilter = areaFilter:lower()
    end
    local areaList = {}
    for uid, area in pairs(areas) do
        if not areaFilter or uid:lower():find(areaFilter) or area.name:lower():find(areaFilter) then
            table.insert(areaList, {uid = uid, name = area.name, levelMin = area.levelMin or 0, levelMax = area.levelMax or 100})
        end
    end
    -- Sort areas by name
    table.sort(areaList, function(a, b) return a.name:lower() < b.name:lower() end)
    -- Display the areas in a table format
    if #areaList == 0 then
        rune.echo("No areas found matching filter: '" .. (areaFilter or "all") .. "'")
    else
        rune.echo("Areas:")
        rune.echo("ID          | Area Name                                       | Level Min | Level Max")
        rune.echo("------------|------------------------------------------------|-----------|-----------")
        for _, area in ipairs(areaList) do
            local uid = area.uid
            if string.find(uid, "nomap") then uid = "nomap" end
            local levelMin = area.levelMin or 0
            local levelMax = area.levelMax or 100
            local output = string.format("%-12s | %-46s | %-9d | %-9d",
                uid, area.name, levelMin, levelMax)
            rune.echo(output)
        end
    end
end

function aliasMapperAreaGoto(name, line, wildcards)
    -- Get the destination area search string
    local areaSearch = wildcards[1]
    if not areaSearch or areaSearch == "" then
        rune.echo("Usage: area goto <area name>")
        return
    end
    
    -- Get current room as source
    local sourceUID = tostring(room.info.num)
    if not sourceUID then
        rune.echo("Error: Could not determine your current location")
        return
    end
    
    -- Find the area using the search string
    local areaUID = findFirstMatchingArea(areaSearch)
    if not areaUID then
        rune.echo("Error: Could not find any area matching '" .. areaSearch .. "'")
        return
    end
    
    -- Inform the user which area was found
    rune.echo("Found area: " .. areas[areaUID].name .. " (" .. areaUID .. ")")
    
    -- Check if we're already in this area
    if rooms[sourceUID] and rooms[sourceUID].area == areaUID then
        rune.echo("You are already in that area!")
        return
    end
    
    -- Find the nearest room in the target area
    local playerLevel = effectiveLevel()
    local destUID, path, error = findNearestInArea(sourceUID, areaUID, playerLevel)
    
    if not path then
        rune.echo("Error finding path: " .. error)
        return
    end
    
    -- Show the target room that was found
    rune.echo("Found nearest room in area: " .. rooms[destUID].name .. " (" .. destUID .. ")")
    
    -- Convert path to speedwalk and execute
    local speedwalk = constructSpeedwalk(path)
    rune.echo("Navigating to area via: " .. speedwalk)
    rune.send(speedwalk)
end

function aliasAreaUpdate(name, line, wildcards)
    -- Update details of areas in the area table
    local areaUID = wildcards[1]
    local action = wildcards[2]
    local arguments = wildcards[3]
    if not areas[areaUID] then
        rune.echo("Error: Area " .. areaUID .. " does not exist")
        return
    end
    if action == "name" then
        areas[areaUID].name = arguments
        rune.echo("Area " .. areaUID .. " name updated to: " .. arguments)
    end
end

function mapperDisplayExits(name, line, wildcards)
    -- Display exits for the current room
    local currentRoom = tostring(room.info.num)
    if not currentRoom or not rooms[currentRoom] then
        rune.echo("Error: Could not determine your current location")
        return
    end
    
    local exitsList = exits[currentRoom]
    if not exitsList or #exitsList == 0 then
        rune.echo("No exits available from this room.")
        return
    end
    
    rune.echo("Exits from " .. rooms[currentRoom].name .. " (" .. currentRoom .. "):")
    rune.echo("ID     | Direction            | Destination Room                                           | Area            | Lvl | Flags")
    rune.echo("------------------------------|------------------------------------------------------------|-----------------------------------------")
    for _, exit in ipairs(exitsList) do
        local lvl = exit.level
        if lvl == nil or lvl == 0 then lvl = "" end

        local output = string.format("%6d | %-20s | %-58s | %-15s | %-3s | %s",
            exit.id,
            exit.dir,
            (rooms[exit.touid] and rooms[exit.touid].name or "Unknown") .. " (" .. exit.touid .. ")",
            (rooms[exit.touid] and rooms[exit.touid].area or "Unknown"),
            lvl,
            exit.flags or "")
        rune.echo(output)
    end
end

function aliasGoWhere(name, line, wildcards)
    -- Run to the first room in the gowhereRoomIDs list
    if #gowhereRoomIDs == 0 then
        rune.echo("No gowhere targets set. These should populate automatically when you use the 'where' command.")
        return
    end
    local targetRoom = gowhereRoomIDs[1]
    rune.send("mapper goto " .. targetRoom)
end

function mapperDisplayPortals(name, line, wildcards)
    -- Display all handheld portal exits in the database, regardless of player level.
    -- (Pathfinding still respects level requirements; this listing is informational.)
    local portalExits = {}
    if exits['*'] then
        for _, exit in ipairs(exits['*']) do
            table.insert(portalExits, exit)
        end
    end

    if #portalExits == 0 then
        rune.echo("No handheld portals defined.")
        return
    end

    rune.echo("Available portals (all levels):")
    rune.echo("ID     | Direction                    | Destination Room                                     | Area          | Lvl | Flags")
    rune.echo("--------------------------------------|------------------------------------------------------|---------------|-----|-------------------")

    for _, exit in ipairs(portalExits) do
        local output = string.format("%6d | %-28s | %-52s | %-13s | %-3d | %s",
            exit.id,
            exit.dir,
            (rooms[exit.touid] and rooms[exit.touid].name or "Unknown") .. " (" .. exit.touid .. ")",
            (rooms[exit.touid] and rooms[exit.touid].area or "Unknown"),
            tonumber(exit.level) or 0,
            (exit.flags or ""))

        rune.echo(output)
    end
end

function setGowhereRoomIDs(roomUIDstring)
    -- Set the gowhereRoomID manually
    if roomUIDstring == nil or roomUIDstring == "" then
        rune.echo("No room UIDs provided to set gowhere targets.")
        return
    end
    gowhereRoomIDs = {} -- Reset the list
    gowhereRoomSet = {} -- Reset the set
    local roomUIDs = string.split(roomUIDstring, "|")
    for _, roomUID in ipairs(roomUIDs) do
        if roomUID ~= tostring(room.info.num) then
            table.insert(gowhereRoomIDs, roomUID)
            gowhereRoomSet[roomUID] = true
        end
    end
    rune.echo("GMCP Mapper: gowhere target list set to: " .. roomUIDstring)
end

function triggerStartWhere(name, line, wildcards)
    -- Add a temporary trigger to capture the next line of output
    rune.trigger.regex("(.+)", function (matches,ctx)
       triggerCaptureWhere(ctx,matches)
    end, {name = "trg_capture_where_temp"})
end

function triggerCaptureWhere(triggerctx, wildcards)
    rune.trigger.remove("trg_capture_where_temp")
    -- This trigger captures the next line of output after the "where" command
    -- and sets gowhereRoomID based on the captured room name.
    if wildcards[1]:find("There is no") then
        rune.echo("GMCP Mapper: No matching room found for 'where' command.")
        return
    end
    local roomname = string.sub(wildcards[1],32) -- First 31 characters are the mob name
    local currentArea = room.info.zone
    local whereTargets = findRoomExact(roomname, currentArea, tostring(room.info.num))
    local currentRoom = tostring(room.info.num)
    gowhereRoomIDs = {} -- Reset the gowhereRoomIDs list
    gowhereRoomSet = {} -- Reset the gowhereRoomSet
    rune.dbg("Searching for room: '" .. roomname .. "' in area: '" .. currentArea .. "'")

    if whereTargets ~= nil then
        -- Defensive filter: ensure all selected targets are from the player's current area.
        local filtered = {}
        for _, roomUID in ipairs(string.split(whereTargets, "|")) do
            if rooms[roomUID] and rooms[roomUID].area == currentArea then
                table.insert(filtered, roomUID)
            end
        end

        if #filtered == 0 then
            rune.echo("No matching room found for '" .. roomname .. "' in current area.")
            return
        end

        local orderedTargets = orderRoomsGreedy(filtered)
        setGowhereRoomIDs(orderedTargets)
    else
        rune.echo("No matching room found for '" .. roomname .. "' in current area.")
    end
end

function orderRoomsGreedy(roomUIDList)
    -- Get current room as source
    local sourceUID = tostring(room.info.num)
    if not sourceUID then
        return roomUIDList -- Return original list if we can't determine current location
    end
    
    -- Convert string to table if needed
    if type(roomUIDList) == "string" then
        roomUIDList = string.split(roomUIDList, "|")
    end
    
    -- Return early if empty or only one room
    if #roomUIDList == 0 or #roomUIDList == 1 then
        return table.concat(roomUIDList, "|")
    end
    
    local orderedRooms = {}
    local remainingRooms = {}
    
    -- Copy valid rooms to our working list
    for _, roomUID in ipairs(roomUIDList) do
        if rooms[roomUID] then
            table.insert(remainingRooms, roomUID)
        end
    end
    
    -- Simple greedy algorithm - always pick the closest room next
    local currentRoom = sourceUID
    
    while #remainingRooms > 0 do
        local bestRoom = nil
        local bestEstimate = math.huge
        local bestIndex = 0
        
        -- Find the closest room based on our heuristic
        for i, roomUID in ipairs(remainingRooms) do
            local estimate = estimateDistance(currentRoom, roomUID)
            
            -- If rooms are in the same area, give them preference
            if rooms[currentRoom] and rooms[roomUID] and 
               rooms[currentRoom].area == rooms[roomUID].area then
                estimate = estimate - 0.5
            end
            
            if estimate < bestEstimate then
                bestEstimate = estimate
                bestRoom = roomUID
                bestIndex = i
            end
        end
        
        -- Add the best room to our ordered list
        table.insert(orderedRooms, bestRoom)
        table.remove(remainingRooms, bestIndex)
        
        -- Update current position
        currentRoom = bestRoom
    end
    
    -- Return in the same format as the input
    return table.concat(orderedRooms, "|")
end


--- Global Quest (GQ) handling
function triggerGQJoin(name, line, wildcards)
    -- Trigger for joining a global quest
    GQinProgress = true
end

function mapperTriggerGQDone(name, line, wildcards)
    GQinProgress = false
end

function getRoomDetails(roomUID)
    -- Get detailed information about a room
    if not rooms[roomUID] then
        return nil, "Room " .. roomUID .. " does not exist"
    end
    
    local room = rooms[roomUID]
    -- Return room name, area, and flags.
    -- Don't return a table, as this is used by an external plugin.
    return room.name,room.area,room.flags or nil
end

function getAreaName(areaUID)
    -- Get the name of an area by its UID
    if not areas[areaUID] then
        return nil
    end
    
    return areas[areaUID].name
end

function getAreaInfo(areaUID)
    if not areas[areaUID] then
        return nil
    end
    return {
        name = areas[areaUID].name,
        levelMin = areas[areaUID].levelMin,
        levelMax = areas[areaUID].levelMax,
        keyword = areaUID
    }
end

function getAllAreaKeywords()
    local keywords = {}
    for keyword in pairs(areas) do
        table.insert(keywords, keyword)
    end
    table.sort(keywords)
    return keywords
end

function getExitRoom(exitID)
    -- Get the room UID for an exit by its ID
    -- first check if the exit is in the current room before scanning all the exits
    exitID = tonumber(exitID)
    local gmcpRoomID = tostring(room.info.num)
    if gmcpRoomID then
        if exits[gmcpRoomID] then
            for i, exit in ipairs(exits[gmcpRoomID]) do
                if exit.id == tonumber(exitID) then
                    return gmcpRoomID -- Return the current room UID if this exit exists here
                end
            end
        end
    end

    for roomUID,exitList in pairs(exits) do
        for _, exit in ipairs(exitList) do
            if exit.id == tonumber(exitID) then
                return roomUID -- Return the room UID where this exit exists
            end
        end
    end
    return nil, "Exit " .. exitID .. " does not exist"
end

function getExits(roomUID)
    -- Get a list of the directions for all exits in a room, return them as a pipe-delimited string
    if not roomUID or roomUID == "" then
        return nil, "Room UID cannot be empty"
    end
    if not exits[roomUID] then
        return nil, "No exits found for room " .. roomUID
    end
    
    -- Define the standard exit direction order
    local standardOrder = {"n", "s", "e", "w", "u", "d"}
    local standardExits = {}
    local customExits = {}
    
    -- Separate standard exits from custom exits
    for _, exit in ipairs(exits[roomUID]) do
        local isStandard = false
        for _, stdDir in ipairs(standardOrder) do
            if exit.dir == stdDir then
                standardExits[exit.dir] = true
                isStandard = true
                break
            end
        end
        if not isStandard then
            table.insert(customExits, exit.dir)
        end
    end
    
    -- Build the sorted exit list
    local exitList = {}
    
    -- Add standard exits in defined order
    for _, dir in ipairs(standardOrder) do
        if standardExits[dir] then
            table.insert(exitList, dir)
        end
    end
    
    -- Add custom exits (they remain in their original order)
    for _, dir in ipairs(customExits) do
        table.insert(exitList, dir)
    end
    
    exitList = table.concat(exitList, "|")
    rune.dbg("Exits for room " .. roomUID .. ": " .. exitList)
    return exitList
end

function setExitDoorCommand(roomUID, exitID, command)
    -- Validate parameters
    if not roomUID or roomUID == "" then
        return false, "Room UID cannot be empty"
    end
    
    exitID = tonumber(exitID)
    if not exitID then
        return false, "Exit ID must be a number"
    end
    
    -- Check if the room exists
    if not exits[roomUID] then
        return false, "No exits found for room " .. roomUID
    end
    
    -- Process the command parameter
    local newCommand = nil
    if command:lower() == "clear" then
        newCommand = nil
    else
        newCommand = command
    end
    
    -- Find and update the exit
    local exitFound = false
    for i, exit in ipairs(exits[roomUID]) do
        if exit.id == exitID then
            -- Found the exit, update its doorcommand
            local oldCommand = exit.doorcommand
            exit.doorcommand = newCommand
            exitFound = true
            rooms[roomUID].changed = true -- Mark the room as changed
            return true, "Exit ID " .. exitID .. " doorcommand changed from '" .. (oldCommand or "nil") .. "' to '" .. (newCommand or "nil") .. "'"
        end
    end
    
    if not exitFound then
        return false, "Exit with ID " .. exitID .. " not found in room " .. roomUID
    end
end

function deleteExit(roomUID, exitID)
    -- Validate parameters
    if not roomUID or roomUID == "" then
        return false, "Room UID cannot be empty"
    end
    
    exitID = tonumber(exitID)
    if not exitID then
        return false, "Exit ID must be a number"
    end
    
    -- Check if the room exists
    if not exits[roomUID] then
        return false, "No exits found for room " .. roomUID
    end
    
    -- Look for the exit with the matching ID
    for i, exit in ipairs(exits[roomUID]) do
        if exit.id == exitID then
            -- Found the exit, remove it from the table and index
            table.remove(exits[roomUID], i)
            if exitDirIndex[roomUID] and exit.dir then
                exitDirIndex[roomUID][exit.dir] = nil
            end
            return true, "Exit with ID " .. exitID .. " deleted from room " .. roomUID
        end
    end
    
    return false, "Exit with ID " .. exitID .. " not found in room " .. roomUID
end

function setExitLevel(roomUID, exitID, level)
    -- Validate parameters
    if not roomUID or roomUID == "" then
        return false, "Room UID cannot be empty"
    end
    
    exitID = tonumber(exitID)
    if not exitID then
        return false, "Exit ID must be a number"
    end
    
    -- Check if the room exists
    if not exits[roomUID] then
        return false, "No exits found for room " .. roomUID
    end
    
    -- Process the level parameter
    local newLevel = 0
    if level:lower() == "clear" then
        newLevel = 0
    else
        newLevel = tonumber(level)
        if not newLevel then
            return false, "Level must be a number or 'clear'"
        end
        
        -- Validate level range
        if newLevel < 0 or newLevel > 201 then
            return false, "Level must be between 0 and 201"
        end
    end
    
    -- Find and update the exit
    local exitFound = false
    for i, exit in ipairs(exits[roomUID]) do
        if exit.id == exitID then
            -- Found the exit, update its level
            local oldLevel = exit.level or 0
            exit.level = newLevel
            exitFound = true
            rooms[roomUID].changed = true -- Mark the room as changed
            return true, "Exit ID " .. exitID .. " level changed from " .. oldLevel .. " to " .. newLevel
        end
    end
    
    if not exitFound then
        return false, "Exit with ID " .. exitID .. " not found in room " .. roomUID
    end
end

function toggleExitFlag(roomUID, exitID, flag)
    -- Validate parameters
    if not roomUID or roomUID == "" then
        return false, "Room UID cannot be empty"
    end
    
    exitID = tonumber(exitID)
    if not exitID then
        return false, "Exit ID must be a number"
    end
    
    -- Check if the flag is valid
    local validFlags = {nogq=true, portal=true, recall=true, door=true, default=true, disabled=true}
    if not validFlags[flag] then
        return false, "Invalid flag: '" .. flag .. "'. Valid flags are: nogq, portal, recall, door, default"
    end
    
    -- Check if the room exists
    if not exits[roomUID] then
        return false, "No exits found for room " .. roomUID
    end
    
    -- Find the exit with the matching ID
    local exitFound = false
    local targetExit = nil
    
    for i, exit in ipairs(exits[roomUID]) do
        if exit.id == exitID then
            exitFound = true
            targetExit = exit
            break
        end
    end
    
    if not exitFound then
        return false, "Exit with ID " .. exitID .. " not found in room " .. roomUID
    end
    
    -- Initialize flags if not present
    if not targetExit.flags then
        targetExit.flags = ""
    end
    
    -- Check if the flag is already set
    local flagSet = targetExit.flags:find(flag) ~= nil
    local newFlags = ""
    
    if flagSet then
        -- Remove the flag
        local flags = {}
        for f in targetExit.flags:gmatch("([^,]+)") do
            if f:match("^%s*(.-)%s*$") ~= flag then
                table.insert(flags, f)
            end
        end
        newFlags = table.concat(flags, ",")
        if newFlags == "" then
            newFlags = nil
        end
    else
        -- Add the flag
        -- Special handling for 'default' flag - must remove from any other exit first
        if flag == "default" then
            -- Look through all exits to find and remove the default flag
            for roomID, exitList in pairs(exits) do
                for _, otherExit in ipairs(exitList) do
                    if otherExit.flags and otherExit.flags:find("default") then
                        -- Remove default flag from other exit
                        local flags = {}
                        for f in otherExit.flags:gmatch("([^,]+)") do
                            if f:match("^%s*(.-)%s*$") ~= "default" then
                                table.insert(flags, f)
                            end
                        end
                        otherExit.flags = table.concat(flags, ",")
                        if otherExit.flags == "" then
                            otherExit.flags = nil
                        end
                        
                        rooms[roomID].changed = true -- Mark the room as changed
                        rune.echo("Removed 'default' flag from exit ID " .. otherExit.id)
                        break
                    end
                end
            end
        end
        
        -- Now add the flag to our target exit
        if targetExit.flags and targetExit.flags ~= "" then
            newFlags = targetExit.flags .. "," .. flag
        else
            newFlags = flag
        end
    end
    
    -- Update the exit flags
    targetExit.flags = newFlags
    rooms[roomUID].changed = true -- Mark the room as changed
    return true, "Exit ID " .. exitID .. " flag '" .. flag .. "' " .. (flagSet and "removed" or "added") .. ". New flags: " .. (newFlags or "none")
end


function aliasMapperExit(name,line,wildcards)
    -- Used to manage exits with the mapper.
    -- Usage: mapper exit <exitID> <action> [<param>]
    -- Actions:
    -- flag <flag> - Toggle a flag for the exit
    -- doorcommand <command> - Set a custom door command for the exit
    -- doorcommand clear - Clear the custom door command
    -- level <level> - Set the level requirement for the exit
    -- delete - Delete the exit

    local exitID = wildcards[2]
    local action = wildcards[3]
    local roomUID = getExitRoom(exitID)
    if not roomUID then
        rune.echo("Error: Exit roomUID not found for exit ID " .. exitID)
        return
    end

    if #wildcards < 2 then
        rune.echo("Usage: mapper exit <exitID> <action> [<param>]")
    return end
    if action == "delete" then
        -- Delete the exit
        local success, message = deleteExit(roomUID, exitID)
        if success then
            rune.echo(message)
        else
            rune.echo("Error: " .. message)
        end
        return
    end
    if action == "flag" then
        -- Toggle a flag for the exit
        if #wildcards < 4 then
            rune.echo("Usage: mapper exit <exitID> flag <flag>")
            return
        end
        local flag = wildcards[4]
        local success, message = toggleExitFlag(roomUID, exitID, flag)
        if success then
            rune.echo(message)
        else
            rune.echo("Error: " .. message)
        end
        return
    end
    if action == "doorcommand" then
        -- Set a custom door command for the exit
        if #wildcards < 4 then
            rune.echo("Usage: mapper exit <exitID> doorcommand <command>")
            return
        end
        local command = wildcards[4]
            -- Set the door command
            local success, message = setExitDoorCommand(roomUID, exitID, command)
        if success then
            rune.echo(message)
        else
            rune.echo("Error: " .. message)
        end
        return
    end
    if action == "level" then
        -- Set the level requirement for the exit
        if #wildcards < 4 then
            rune.echo("Usage: mapper exit <exitID> level <level>")
            return
        end
        local level = wildcards[4]
        local success, message = setExitLevel(roomUID,exitID,level)
        if success then
            rune.echo(message)
        else
            rune.echo("Error: " .. message)
        end
        return
    end
end

function updateRoomGMCP(roomUID, roomName, roomArea, roomExits)
    -- Validate inputs
    if not initialized then return end
    if not roomUID or not roomName or not roomArea then
        rune.dbg("GMCP Mapper: Invalid room data received")
        return false
    end
    -- Temporary cleanup code
    if rooms["-1"] then 
        rune.echo("GMCP Mapper: Removing invalid room UID '-1'")
        rooms["-1"] = nil -- Remove the invalid room
    end

    if roomUID == "-1" then return end -- Ignore invalid room UID
    -- Check if area exists in the areas table, if not, add it
    if not areas[roomArea] then
        rune.echo("GMCP Mapper: Adding new area: " .. roomArea)
        areas[roomArea] = {name = roomArea}
        -- Area metadata is persisted by saveMapperData()
    end
    
    -- Update or create the room
    local roomChanged = false
    
    if not rooms[roomUID] then
        -- Room doesn't exist, create it
        rune.echo("GMCP Mapper: Adding new room: " .. roomName .. " (" .. roomUID .. ") in area " .. roomArea)
        rooms[roomUID] = {
            uid = roomUID,
            name = roomName,
            area = roomArea,
            changed = true
        }
        roomChanged = true
    else
        -- Room exists, check if it needs updating
        if rooms[roomUID].name ~= roomName or rooms[roomUID].area ~= roomArea then
            rune.echo("GMCP Mapper: Updating room: " .. roomUID)
            rooms[roomUID].name = roomName
            rooms[roomUID].area = roomArea
            rooms[roomUID].changed = true
            roomChanged = true
        end
    end
    
    -- Initialize exits table for this room if it doesn't exist
    if not exits[roomUID] then
        exits[roomUID] = {}
        exitDirIndex[roomUID] = {}
    end
    if not exitDirIndex[roomUID] then
        exitDirIndex[roomUID] = {}
    end

    -- Process exits
    if roomExits then
        -- First, convert the key-value format to our internal format
        for dir, touid in pairs(roomExits) do
            -- O(1) lookup using direction index
            local exit = exitDirIndex[roomUID][dir]

            if exit then
                -- Exit exists, update it if needed
                if exit.touid ~= tostring(touid) then
                    exit.touid = tostring(touid)
                    rooms[roomUID].changed = true
                    roomChanged = true
                end
            else
                -- Generate a new exit ID
                local newExitID = generateExitID()

                -- Create and add new exit
                local newExit = {
                    id = newExitID,
                    dir = dir,
                    touid = tostring(touid),
                    level = 0,
                    flags = ""
                }
                table.insert(exits[roomUID], newExit)
                exitDirIndex[roomUID][dir] = newExit

                rooms[roomUID].changed = true
                roomChanged = true
            end
        end
    end    
    -- If changes were made, mark room data as dirty for saveMapperData()
    if roomChanged then rooms[roomUID].changed = true end
end

function setRoomNoRecall(name, line, wildcards)
    -- Set the no-recall flag for a room
    local roomUID = tostring(room.info.num)

    if not roomUID or not rooms[roomUID] then
        rune.echo("Error: Could not determine your current location")
        return
    end
    
    -- Add the flag if needed
    if rooms[roomUID].norecall == nil or rooms[roomUID].norecall == 0 then
       rooms[roomUID].norecall = 1
       rune.echo("Added 'norecall' flag to room " .. roomUID)
       rooms[roomUID].changed = true -- Mark the room as changed
    end
end

function setRoomNoPortal(name, line, wildcards)
    -- Set the no-recall flag for a room
    local roomUID = tostring(room.info.num)

    if not roomUID or not rooms[roomUID] then
        rune.echo("Error: Could not determine your current location")
        return
    end
    
    -- Add the flag if needed
    if rooms[roomUID].noportal == nil or rooms[roomUID].noportal == 0 then
       rooms[roomUID].noportal = 1
       rune.echo("Added 'noportal' flag to room " .. roomUID)
       rooms[roomUID].changed = true -- Mark the room as changed
    end
end


function aliasMapperRoomInfo(name, line, wildcards)
    -- Display information about the current room
    local roomUID = tostring(room.info.num)
    if wildcards[2] ~= nil and wildcards[2] ~= "" then
        -- Override roomUID
        roomUID = wildcards[2]
    end

    if not roomUID or not rooms[roomUID] then
        rune.echo("Error: Could not determine your current location")
        return
    end
    
    local room = rooms[roomUID]
    local areaName = areas[room.area] and areas[room.area].name or "Unknown"
    
    rune.echo("Room Info:")
    rune.echo("UID: " .. roomUID)
    rune.echo("Name: " .. room.name)
    rune.echo("Area: " .. areaName)
    --rune.echo("NoRecall: " .. room.norecall or "unknown")
    --rune.echo("NoPortal: " .. room.noportal or "unknown")
    
    -- Display exits
    if exits[roomUID] and #exits[roomUID] > 0 then
        rune.echo("Exits:")
        for _, exit in ipairs(exits[roomUID]) do
            local destRoom = rooms[exit.touid] and rooms[exit.touid].name or "Unknown"
            rune.echo(string.format("  %s -> %s (ID: %d)", exit.dir, destRoom, exit.id))
        end
    else
        rune.echo("No exits available from this room.")
    end
end

function aliasMapperRoomDelete(name, line, wildcards)
    local roomUID = tostring(wildcards[1] or "")
    if roomUID == "" then
        rune.echo("Usage: mapper room <id> delete")
        return
    end

    if not rooms[roomUID] then
        rune.echo("Error: Room " .. roomUID .. " does not exist")
        return
    end

    local removedFromCount = 0
    local removedToCount = 0

    -- Remove all exits originating from the room.
    if exits[roomUID] then
        removedFromCount = #exits[roomUID]
        exits[roomUID] = nil
        exitDirIndex[roomUID] = nil
    end

    -- Remove all exits in other rooms that point to this room.
    for sourceUID, exitList in pairs(exits) do
        if type(exitList) == "table" then
            local kept = {}
            local removedHere = 0
            for _, ex in ipairs(exitList) do
                if tostring(ex.touid) == roomUID then
                    removedHere = removedHere + 1
                    -- Remove from direction index
                    if exitDirIndex[sourceUID] and ex.dir then
                        exitDirIndex[sourceUID][ex.dir] = nil
                    end
                else
                    table.insert(kept, ex)
                end
            end
            if removedHere > 0 then
                exits[sourceUID] = kept
                removedToCount = removedToCount + removedHere
                if rooms[sourceUID] then
                    rooms[sourceUID].changed = true
                end
            end
        end
    end

    -- Remove pending path hooks and notes for this room.
    if type(pendingSW) == "table" then
        pendingSW[roomUID] = nil
    end
    if type(roomnotes) == "table" then
        roomnotes[roomUID] = nil
    end
    if type(gowhereRoomIDs) ~= "table" then
        gowhereRoomIDs = {}
        gowhereRoomSet = {}
    else
        gowhereRoomIDs = arrayRemoveEntry(gowhereRoomIDs, roomUID)
        gowhereRoomSet[roomUID] = nil
    end

    local deletedName = rooms[roomUID].name or "Unknown"
    rooms[roomUID] = nil

    rune.echo(string.format("Deleted room %s (%s).", roomUID, deletedName))
    rune.echo(string.format("Removed %d outgoing exits and %d incoming exits.", removedFromCount, removedToCount))
end

function aliasMapperZoneRooms(name, line, wildcards)
    local currentArea = room.info.zone
    if not currentArea or currentArea == "" then
        rune.echo("Error: Could not determine your current area")
        return
    end

    local areaName = (areas[currentArea] and areas[currentArea].name) or currentArea
    local zoneRooms = {}

    for uid, room in pairs(rooms) do
        if type(room) == "table" and room.area == currentArea then
            table.insert(zoneRooms, {
                uid = tostring(uid),
                name = room.name or "Unknown"
            })
        end
    end

    if #zoneRooms == 0 then
        rune.echo("No rooms found in current area: " .. areaName .. " (" .. currentArea .. ")")
        return
    end

    table.sort(zoneRooms, function(a, b)
        local aNum = tonumber(a.uid)
        local bNum = tonumber(b.uid)
        if aNum and bNum then
            return aNum < bNum
        elseif aNum then
            return true
        elseif bNum then
            return false
        end
        return a.uid < b.uid
    end)

    rune.echo("Rooms in current area: " .. areaName .. " (" .. currentArea .. ")")
    rune.echo("ID         | Room Name")
    rune.echo("-----------|------------------------------------------------------------")
    for _, entry in ipairs(zoneRooms) do
        rune.echo(string.format("%-10s | %s", entry.uid, entry.name))
    end
    rune.echo("Total rooms in area: " .. tostring(#zoneRooms))
end

function aliasMapperExitInfo(name, line, wildcards)
    -- Display information about a specific exit
    local exitID = tonumber(wildcards[2])
    if not exitID then
        rune.echo("Usage: mapper exitinfo <exitID>")
        return
    end
    
    -- Find the exit in all rooms
    local foundExit = nil
    for roomUID, exitList in pairs(exits) do
        for _, exit in ipairs(exitList) do
            if exit.id == exitID then
                foundExit = {roomUID = roomUID, exit = exit}
                break
            end
        end
        if foundExit then break end
    end
    
    if not foundExit then
        rune.echo("Error: Exit with ID " .. exitID .. " not found")
        return
    end
    
    local room = rooms[foundExit.roomUID]
    local areaName = areas[room.area] and areas[room.area].name or "Unknown"
    
    rune.echo("Exit Information:")
    rune.echo("Source room: " .. foundExit.roomUID)
    rune.echo("Target room: " .. foundExit.exit.touid)
    rune.echo("Area: " .. areaName)
    rune.echo("Direction: " .. foundExit.exit.dir)
    rune.echo("level: " .. foundExit.exit.level or 1)

    rune.echo("Flags: " .. (foundExit.exit.flags or "None"))
end

function aliasMapperProfile(name, line, wildcards)
    -- Toggle / set pathfinding profile output
    local arg = wildcards[1]
    if arg then arg = arg:lower():gsub("^%s+", ""):gsub("%s+$", "") end

    if arg == "on" or arg == "1" or arg == "true" then
    mapperPathProfile = true
        rune.store.set("mapper_profile", "1")
    elseif arg == "off" or arg == "0" or arg == "false" then
        mapperPathProfile = false
        rune.store.set("mapper_profile", "0")
    elseif arg == nil or arg == "" then
        -- toggle
        mapperPathProfile = not (mapperPathProfile == true)
        rune.store.set("mapper_profile", mapperPathProfile and "1" or "0")
    else
        rune.echo("Usage: mapper profile [on|off]")
        return
    end
    rune.echo("Mapper pathfinding profile: " .. (mapperPathProfile and "ON" or "OFF"))
end

function aliasMapperGQState(name, line, wildcards)
    local playerLevel = effectiveLevel() or 0
    local currentRoom = tostring(room.info.num)
    local currentNoPortal = false
    local currentNoRecall = false

    if currentRoom and rooms[currentRoom] then
        currentNoPortal = rooms[currentRoom].noportal == 1
        currentNoRecall = rooms[currentRoom].norecall == 1
    end

    local total = 0
    local nogqTotal = 0
    local levelBlocked = 0
    local nogqBlockedNow = 0
    local usableNow = 0

    for _, exit in ipairs(exits["*"] or {}) do
        total = total + 1
        local reqLevel = tonumber(exit.level) or 0
        local isNogq = hasFlag(exit.flags, "nogq")

        if isNogq then nogqTotal = nogqTotal + 1 end
        if reqLevel > playerLevel then
            levelBlocked = levelBlocked + 1
        end

        local blockedByNogq = isNogq and GQinProgress
        if blockedByNogq then
            nogqBlockedNow = nogqBlockedNow + 1
        end

        if reqLevel <= playerLevel and not blockedByNogq then
            usableNow = usableNow + 1
        end
    end

    local roomGateNote = "none"
    if currentNoPortal and currentNoRecall then
        roomGateNote = "noportal+norecall"
    elseif currentNoPortal then
        roomGateNote = "noportal"
    elseif currentNoRecall then
        roomGateNote = "norecall"
    end

    rune.echo("Mapper GQ State:")
    rune.echo("  GQinProgress: " .. tostring(GQinProgress))
    rune.echo("  Player level for portal checks: " .. tostring(playerLevel))
    rune.echo("  Handheld portal entries (source '*'): total=" .. total .. ", nogq=" .. nogqTotal)
    rune.echo("  Eligible by level now: " .. tostring(total - levelBlocked) .. " (blocked by level: " .. levelBlocked .. ")")
    rune.echo("  Blocked by nogq right now: " .. nogqBlockedNow .. " (only when GQinProgress=true)")
    rune.echo("  Usable now (level + nogq checks): " .. usableNow)
    rune.echo("  Current room gating flags: " .. roomGateNote)
end

function saveMapperData()
    if not mapperDataValid then
        rune.echo(acs("@RWarning: mapper data is invalid; save disabled to protect backups.@w"))
        return false
    end
    -- Prepare a table with all mapper data
    local dataToSave = {
        areas = areas,
        rooms = rooms,
        exits = exits,
        areanotes = areanotes,
        roomnotes = roomnotes,
        timestamp = os.time()
    }
    mapperShiftBackups()
    
    -- Serialize the data
    local serialized
    local success, err = pcall(function()
        serialized = cbor.encode(dataToSave)
        return true
    end)
    
    if not success or not serialized then
        rune.echo("Error serializing mapper data: " .. (err or "unknown error"))
        return false
    end
    
    -- Open file for writing in binary mode
    local file, err = io.open(mapperdbpath, "wb")
    if not file then
        rune.echo("Error opening file for saving: " .. (err or "unknown error"))
        return false
    end
    
    -- Write to file and close
    file:write(serialized)
    file:close()
    
    -- Calculate statistics for feedback
    local roomCount = 0
    for _ in pairs(rooms) do roomCount = roomCount + 1 end
    
    local exitCount = 0
    for _, exitList in pairs(exits) do 
        exitCount = exitCount + #exitList
    end
    
    local areaCount = 0
    for _ in pairs(areas) do areaCount = areaCount + 1 end
    
    rune.echo(string.format("Mapper data saved to %s", mapperdbpath))
    rune.echo(string.format("Saved %d areas, %d rooms, and %d exits (%d bytes)", 
        areaCount, roomCount, exitCount, #serialized))
    
    return true
end

local function rebuildExitDirIndex()
    exitDirIndex = {}
    for roomUID, exitList in pairs(exits) do
        if type(exitList) == "table" then
            exitDirIndex[roomUID] = {}
            for _, exit in ipairs(exitList) do
                if exit.dir then
                    exitDirIndex[roomUID][exit.dir] = exit
                end
            end
        end
    end
end

function loadMapperData()
    local data, err = mapperLoadSerializedFile(mapperdbpath)
    if not data then
        mapperWarnInvalidLoad(err or "primary file unreadable")
        for i = 1, mapperBackupCount do
            local backupData = mapperLoadSerializedFile(mapperBackupPath(i))
            if backupData then
                areas = backupData.areas
                rooms = backupData.rooms
                exits = backupData.exits
                areanotes = backupData.areanotes
                roomnotes = backupData.roomnotes
                mapperDataValid = true
                rebuildExitDirIndex()
                nextExitID = nil -- Reset cache so it rebuilds on first use
                rune.echo(acs("@RWarning: restored mapper data from backup " .. tostring(i) .. ".@w"))
                initialized = true
                return true
            end
        end
        mapperDataValid = false
        return false
    end

    areas = data.areas
    rooms = data.rooms
    exits = data.exits
    areanotes = data.areanotes
    roomnotes = data.roomnotes
    mapperDataValid = true
    rebuildExitDirIndex()
    nextExitID = nil -- Reset cache so it rebuilds on first use
        
    -- Calculate statistics for feedback
    local roomCount = 0
    for _ in pairs(rooms) do roomCount = roomCount + 1 end
    
    local exitCount = 0
    for _, exitList in pairs(exits) do 
        exitCount = exitCount + #exitList
    end
    
    local areaCount = 0
    for _ in pairs(areas) do areaCount = areaCount + 1 end
    
    rune.echo(string.format("Mapper data loaded from %s", mapperdbpath))
    rune.echo(string.format("Loaded %d areas, %d rooms, and %d exits", 
        areaCount, roomCount, exitCount))
    
    if data.timestamp then
        rune.echo("Last saved: " .. os.date("%Y-%m-%d %H:%M:%S", data.timestamp))
    end
    
    initialized = true
    return true
end

function aliasRoomNote(name, line, wildcards)
    -- Add a note to the current room
    local roomUID = tostring(room.info.num)
    if not roomUID or not rooms[roomUID] then
        rune.echo("Error: Could not determine your current location")
        return
    end
    
    local noteText = wildcards[1]
    if not noteText or noteText == "" then
        if roomnotes[roomUID] then
        rune.echo("Note for current room:")
        rune.echo(roomnotes[roomUID])
        return
        end
    end    
    if noteText == "clear" then
        -- Clear the note for this room
        roomnotes[roomUID] = nil
        rune.echo("Cleared note for room " .. roomUID)
        return
    end
    roomnotes[roomUID] = noteText
    rune.echo("Added note for room " .. roomUID .. ".")
end

function aliasAreaNote(name,line,wildcards)
    -- Add a note to the current area. An area can have multiple notes.
    local areaUID = room.info.zone
    if not areaUID or not areas[areaUID] then
        rune.echo("Error: Could not determine your current area")
        return
    end
    local noteText = wildcards[1]
    if not noteText or noteText == "" then
        if areanotes[areaUID] then
            rune.echo("Notes for area " .. areaUID .. ":")
            for i, note in ipairs(areanotes[areaUID]) do
                rune.echo(string.format("%d: %s", i, note))
            end
        else
            rune.echo("No notes found for area " .. areaUID)
        end
        return
    end
    if noteText == "clear" then
        -- Clear all notes for this area
        areanotes[areaUID] = nil
        rune.echo("Cleared all notes for area " .. areaUID)
        return
    end
    -- Add the note to the area
    if not areanotes[areaUID] then
        areanotes[areaUID] = {}
    end
    table.insert(areanotes[areaUID], noteText)
    rune.echo("Added note to area " .. areaUID .. ". Total notes: " .. #areanotes[areaUID])
end

function aliasMapperCExit(name,line,wildcards)
    newexitSource = tostring(room.info.num)
    newexitCommand = wildcards[1]
    newexitType = "cexit"
    if name == "alias_mapper_createportal" then
        newexitType = "portal"
    end
    if not newexitSource or newexitSource == "" then
        rune.echo("Error: Could not determine your current location")
        return
    end
    rune.echo("Hold still for a moment, executing :"..newexitCommand)
    rune.send(newexitCommand)
    rune.timer.after(2,function()
       createCustomExit()
    end)
end

function aliasMapperCreateExit(name, line, wildcards)
    -- Create an exit between two rooms
    -- Usage: mapper createexit <targetid> <direction>     (source = current room)
    --   or:  mapper createexit <sourceid> <targetid> <direction>
    
    local sourceUID, targetUID, direction
    
    if #wildcards == 2 then
        -- Format: mapper createexit <targetid> <direction>
        -- Source is current room
        sourceUID = tostring(room.info.num)
        targetUID = tostring(wildcards[1])
        direction = wildcards[2]
    elseif #wildcards == 3 then
        -- Format: mapper createexit <sourceid> <targetid> <direction>
        sourceUID = tostring(wildcards[1])
        targetUID = tostring(wildcards[2])
        direction = wildcards[3]
    else
        rune.echo("Usage: mapper createexit <targetid> <direction>")
        rune.echo("   or: mapper createexit <sourceid> <targetid> <direction>")
        return
    end
    
    -- Validate source room exists
    if not sourceUID or sourceUID == "" then
        rune.echo("Error: Could not determine source room")
        return
    end
    if not rooms[sourceUID] then
        rune.echo("Error: Source room " .. sourceUID .. " does not exist in the mapper database")
        return
    end
    
    -- Validate target room exists
    if not targetUID or targetUID == "" then
        rune.echo("Error: Target room ID is missing")
        return
    end
    if not rooms[targetUID] then
        rune.echo("Error: Target room " .. targetUID .. " does not exist in the mapper database")
        return
    end
    
    -- Validate direction is not empty
    if not direction or direction == "" then
        rune.echo("Error: Direction/command cannot be empty")
        return
    end
    
    -- Generate exit ID
    local exitID = generateExitID()
    
    -- Create the exit object
    local newExit = {
        id = exitID,
        dir = direction,
        touid = targetUID,
        level = 1,
        flags = nil
    }
    
    -- Initialize exits table for this room if not present
    if not exits[sourceUID] then
        exits[sourceUID] = {}
        exitDirIndex[sourceUID] = {}
    end
    if not exitDirIndex[sourceUID] then
        exitDirIndex[sourceUID] = {}
    end

    -- Add the exit
    table.insert(exits[sourceUID], newExit)
    exitDirIndex[sourceUID][direction] = newExit

    -- Mark the source room as changed
    if not rooms[sourceUID].changed then
        rooms[sourceUID].changed = true
    end

    rune.echo(string.format("Exit created: %s (%d) -[%s]-> %s (%d) [ID: %d]",
        rooms[sourceUID].name, sourceUID,
        direction,
        rooms[targetUID].name, targetUID,
        exitID))
    rune.echo(string.format("Direction contains: %s", direction))
    if direction:find("stop") then
        rune.echo("  → This exit has a 'stop' directive (will halt further pathing)")
    elseif direction:find("pendstop") then
        rune.echo("  → This exit has a 'pendstop' directive (will queue remaining path)")
    end
end

function createCustomExit()
    -- Create a custom exit based on the last command sent
    local destinationRoom = tostring(room.info.num)
    if not destinationRoom or not rooms[destinationRoom] then
        rune.echo("Error: Could not determine destination room for custom exit")
        return
    end

    if newexitSource == destinationRoom then
        rune.echo("Error: Failed to move, so exit will not be created.")
        return
    end

    local flags = ""
    if newexitType == "portal" then
        newexitSource = "*" -- Override source for portals
        flags = "portal"
    end 
  
    local exitID = generateExitID()
    
    -- Create the exit object
    local newExit = {
        id = exitID,
        dir = newexitCommand, -- Custom exits don't have a direction
        touid = destinationRoom, -- Target room is the current room
        doorcommand = newexitCommand,
        level = 1,
        flags = flags
    }
    
    -- Add the exit to the exits table
    if not exits[newexitSource] then
        exits[newexitSource] = {}
        exitDirIndex[newexitSource] = {}
    end
    if not exitDirIndex[newexitSource] then
        exitDirIndex[newexitSource] = {}
    end

    table.insert(exits[newexitSource], newExit)
    exitDirIndex[newexitSource][newexitCommand] = newExit

    -- Mark the source room as changed
    rooms[newexitSource].changed = true
    
    if newexitType == "cexit" then
        rune.echo(string.format("Custom exit created from %s to %s with command '%s' (ID: %d)",
            newexitSource, destinationRoom, newexitCommand, exitID))
    else
        rune.echo(string.format("Portal created from %s to %s with command '%s' (ID: %d)",
            newexitSource, destinationRoom, newexitCommand, exitID))
        rune.echo("Remember to set the level for this portal if required.")
    end
end


function aliasMapperRefreshAreas(name,line,wildcards)
    -- Refresh the areas from the MUD
    rune.trigger.enable("trg_areas_keywords")
    rune.timer.after(3, function(ctx)
        rune.trigger.disable("trg_areas_keywords")
    end)
    rune.echo("Refreshing areas and keywords. One moment....")
    rune.send_raw("areas keywords")

end

function triggerAreasKeywords(name, line, wildcards)
    local areaDetails = {}
    areaDetails.levelMin = tonumber(wildcards[1])
    areaDetails.levelMax = tonumber(wildcards[2])
    if #wildcards == 5 then
        -- Optional area lock is included
        areaDetails.lock = wildcards[3]
        areaDetails.keyword = wildcards[4]
        -- Area name needs to be trimmed
        areaDetails.name = wildcards[5]:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace

    else
        -- No lock, only keyword and name
        areaDetails.keyword = wildcards[3]
        areaDetails.name = wildcards[4]:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
    end
    -- Exceptions
    if areaDetails.name == "The Darkside of the Fractured" then
        --rune.dbg("Special case for The Darkside of the Fractured Lands")
        areaDetails.name = "The Darkside of the Fractured Lands"
    end
    
    -- Add or update the area in the areas table
    if not areas[areaDetails.keyword] then areas[areaDetails.keyword] = {} end
    areas[areaDetails.keyword].name = areaDetails.name
    areas[areaDetails.keyword].levelMin = areaDetails.levelMin
    areas[areaDetails.keyword].levelMax = areaDetails.levelMax
    areas[areaDetails.keyword].lock = areaDetails.lock or nil
    rune.dbg("Area updated: " .. areaDetails.name .. " (" .. areaDetails.keyword .. ")")
end

function updateNotesWindow()
    -- Update the notes window with current room and area notes
    local notes = {}
    local roomUID = tostring(room.info.num)
    
    
    local areaUID = room.info.zone
    table.insert(notes,acs("@G - Mapper Notes -@w"))
    local areaNotes = areanotes[areaUID]
    if areaNotes and #areaNotes > 0 then
        table.insert(notes,"Area Notes:")
        for i, note in ipairs(areaNotes) do
            table.insert(notes,string.format("%d: %s", i, acs(note)))
        end
    else
        table.insert(notes,"No notes for this area.")
    end

    local roomNote = roomnotes[roomUID] or "No note for this room."
    table.insert(notes,"Room Note: " .. acs(roomNote))
    
    rune.pane.replace("notes",table.concat(notes,"\n"))
end

require("aardrune/aliases/gmcp_mapper_aliases")
require("aardrune/triggers/gmcp_mapper_triggers")
rune.pane.create("notes")

initializeMapper()