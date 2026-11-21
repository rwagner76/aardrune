--require "themed_miniwindows"
local cbor = require "aardrune/cbor"

local mobdb = {}
local moblocations = {}
local mobnamelocations = {} -- mobID -> normalized short name -> roomUID -> sightings
local qmob = nil -- Will be populate with the name of the quest mob so we can tag it in scans.
cpmobs = {} -- Will be populated with the names of campaign mobs and the areas or rooms they are in.
gqmobs = {} -- Will be populated with the names of global quest mobs and the areas or rooms they are in.
local cptype = nil -- Will be set to 'area' or 'room' depending on the type of campaign mob.
local autohuntTarget = nil
local hunttrickCounter = 1
local hunttrickTarget = nil
local initialized = false
local scanDirection = nil
cpIndex = 0
gqIndex = 0
local cpRooms = {}
local gqRooms = {}
local mobdbpath = rune.config_dir.."/aardrune/data/mobdb_serialized.dat"
local unclaimedLongNames = {} -- Table to store unclaimed long names
local mobdbAddKeywords = ''
local mobdbAddIndex = 0
local newMobInfo = {}
local priorRoom = nil -- Store the prior room to check for changes
local externalMDBResults = {} -- Table to cache results for mobdb searches from other plugins
local externalMDBIndex = 1
local gqtype
smartScanKeywords = nil
local knownMobsInRoom = {}

function initializeMobDBPlugin()
    rune.dbg("Initializing MobDB plugin...")
    -- Load serialized data from disk.
    loadMobDBFromDisk()
    -- TBD
    rune.timer.every(60,function(ctx) saveMobDBToDisk() end, {name = "timer_save_mobdb"})
    -- OneTimeFix()
end

rune.gmcp.on("room.info", function(data)
   local roomInfoNum = data.num
   removeRoomFromCPGQMob(cpIndex,roomInfoNum)
   if table.contains(gqRooms,roomInfoNum) then
      rune.echo("Removing room " .. roomInfoNum .. " from room list for this GQ target.")
      arrayRemoveEntry(gqRooms,roomInfoNum)
   end
    if roomInfoNum ~= priorRoom then
       -- If the room has changed, reset the mob locations for this room
       unclaimedLongNames = {} -- Reset unclaimed long names
       knownMobsInRoom = {}
       mobdbAddKeywords = '' -- Reset the keywords for mobdbAdd
       mobdbAddIndex = 0 -- Reset the index for mobdbAdd
       priorRoom = roomInfoNum
       rune.trigger.disable("alias_mobadd_select") -- Disable the mobdbAdd select trigger
    end
end)

-- May need to set qmob
--        qmob = qinfo[1] or ""
--        if qmob ~= "" then onquest = true else onquest = false end



function startRoomChars(name, line, wildcards)
    -- Start of roomchars tag noticed, enabled mob capture
    unclaimedLongNames = {} -- Reset unclaimed long names
    knownMobsInRoom = {}
    rune.trigger.enable("trg_mobdb_replace")
end

function endRoomChars(name, line, wildcards)
    -- End of roomchars tag noticed, disabled mob capture
    rune.trigger.disable("trg_mobdb_replace")
end

function updateMobImmunityFromCombat(shortName, rawDamtype)
    local normalizedShort = shortName:lower():gsub("^%s+", ""):gsub("%s+$", "")
    local knownMob = nil
    for _, mob in ipairs(knownMobsInRoom) do
        local mobShort = (mob.shortname or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if mobShort == normalizedShort then
            knownMob = mob
            break
        end
    end
    if not knownMob then
        rune.dbg("MobDB: Could not find mob '" .. shortName .. "' in knownMobsInRoom for immunity update.")
        return false
    end
    local canonicalType = normalizeDamtype(rawDamtype)
    if not canonicalType then
        rune.echo("Unknown damage type: '" .. rawDamtype .. "' (from mob '" .. shortName .. "'). Add to damtypeAliases in robbo_common.lua.")
        return false
    end
    local mobEntry = mobdb[knownMob.id]
    if not mobEntry then return false end
    if not mobEntry.immunities then mobEntry.immunities = {} end
    if table.contains(mobEntry.immunities, canonicalType) then
        return false
    end
    if table.contains(physicaldamtypes, canonicalType) and table.contains(mobEntry.immunities, "allphysical") then
        return false
    end
    if not table.contains(physicaldamtypes, canonicalType) and table.contains(mobEntry.immunities, "allmagical") then
        return false
    end
    table.insert(mobEntry.immunities, canonicalType)
    knownMob.immunities = mobEntry.immunities
    rune.dbg("MobDB: Added immunity '" .. canonicalType .. "' to mob '" .. (mobEntry.names[1] or '?') .. "' (ID: " .. knownMob.id .. ")")
    return true
end

function findMDBMatch(line)
    local zone = room.info.zone
    for e, mob in pairs(mobdb) do
        if mob.roomname == line and mob.area == zone then
            local displayLevel = mob.maxlevel or mob.level
            return true, displayLevel, mob.names[1], mob.keywords, e
        end
    end
    return false, nil, nil, nil, nil
end

function aliasMobdbHelp(name, line, wildcards)
    helpHeader("MobDB / Hunt Commands")
    helpRule()

    helpSection("MobDB")
    helpCmd("mobdb save",                              "Save mob database to disk")
    helpCmd("mobdb find <query>",                      "Search mob database entries")
    helpCmd("mf <query>",                              "(short form)")
    helpCmd("mobdb info <id>",                         "Show full info for one mob record")
    helpCmd("mi <id>",                                 "(short form)")
    helpCmd("mobdb add [text]",                        "Add a mob entry (or prompt/select flow)")
    helpCmd("ma [text]",                               "(short form)")
    helpCmd("ma manual <name>|<kw>|[room]|[level]",    "Manually add a mob (level can be N or N-M)")
    helpCmd("mobdb delete <query>",                    "Delete matching mobdb entry/entries")
    helpCmd("mobdb update <id> <field> <value>",       "Update a field on one mob record")
    helpCmd("  Fields: level (N or N-M), minlevel, maxlevel, area, roomname, notes, keywords", "")
    helpCmd("  name[1-9], addname, removename", "")
    helpCmd("  addroom <uid>, removeroom <uid>", "")
    helpCmd("mu <id> immunity <type>",                 "Toggle immunity (slash/bash/pierce/allphysical/allmagical/etc)")
    helpCmd("mu <id> <field> <value>",                 "(short form)")
    helpCmd("mobwhere <short name>",                   "Show tracked rooms for a specific short mob name")
    helpCmd("mw <short name>",                         "(short form)")
    ColourNote("", "", "")

    helpSection("Checks")
    helpCmd("cp check",                                "Campaign check")
    helpCmd("cp c / cp ch / cp che / cp chec",         "Accepted shorthand variants")
    helpCmd("gq check",                                "Global quest check")
    helpCmd("gq c / gq ch / gq che / gq chec",         "Accepted shorthand variants")
    ColourNote("", "", "")

    helpSection("Hunt Helpers")
    helpCmd("ah <args>",                               "Enable/configure autohunt")
    helpCmd("scan",                                    "Smart scan: uses current Quest/GQ/CP target keywords when known")
    helpCmd("ht <args>",                               "Hunt trick helper")
    helpCmd("cg[r|a|l] [n]",                           "Campaign go helper")
    helpCmd("gg[r|a|l] [n]",                           "GQ go helper")
    helpCmd("planes [mob name]",                       "Find planes targets (GQ > CP > explicit name) and auto-pool when known")
    helpCmd("cgh",                                     "Combined campaign/GQ hunt trick helper")
    helpCmd("cons [args]",                             "Run consider with short-name room tracking")

    helpRule()
end

function aliasmdbSearchHelp()
    helpHeader("MobDB Search Syntax Help")
    helpRule()

    helpSection("Search Flags")
    helpCmd("-name <name>", "Search mob names for a match")
    helpCmd("-keywords <keywords>", "Search mob keywords for a match")
    helpCmd("-area <area>", "Search mob area for a match")
    helpCmd("-roomname <roomname>", "Search mob roomname for a match")
    helpCmd("-id <id>", "Search mob ID for a match")
    helpCmd("-level <level>", "Search mob level for a match (exact)")
    helpCmd("-minlevel <minlevel>", "Search mob level for a minimum level")
    helpCmd("-maxlevel <maxlevel>", "Search mob level for a maximum level")

    --ColourNote("", "", "")
end

function reconstituteTags(tags)
    -- Reconstitute the tags from the mobdb entry
    local tagString = ""
    -- Match part of string to colour
    local colourMatch = {
        ["(Red Aura)"] = acs("@r"),
        ["(R)"] = acs("@r"),
        ["(Golden Aura)"] = acs("@y"),
        ["(G)"] = acs("@y"),
        ["(Player)"] = acs("@W"),
        ["(P)"] = acs("@W"),
        ["(Translucent)"] = acs("@W"),
        ["(T)"] = acs("@W"),
        ["(White Aura)"] = acs("@W"),
        ["(W)"] = acs("@W"),
        ["(Angry)"] = acs("@R"),
        ["(Wounded)"] = acs("@R"),
        ["(Undead)"] = acs("@R"),
        ["(U)"] = acs("@R"),
        ["(Animated)"] = acs("@M"),
        ["(A)"] = acs("@M"),
        ["(Hidden)"] = acs("@w"),
        ["(H)"] = acs("@w"),
        ["(Invis)"] = acs("@w"),
        ["(I)"] = acs("@w"),
        ["(Marked)"] = acs("@D"),
        ["(X)"] = acs("@D"),
        ["(Stealth)"] = acs("@C"),
        ["(S)"] = acs("@c"),
        ["(Flying)"] = acs("@C"),
        ["(F)"] = acs("@c"),
        ["(Diseased)"] = acs("@B"),
        ["(D)"] = acs("@B"),
        ["(Charmed)"] = acs("@C"),
        ["(C)"] = acs("@C")
    }
    local shortflags = false
    for _, tag in ipairs(tags) do
        --rune.dbg("Processing tag: '" .. tag.."'")
        if tag ~= "(OPK)" and tag ~= "HARDCORE " then
            if colourMatch[tag] ~= nil then
                tagString = tagString .. colourMatch[tag] .. tag
            else
                tagString = tagString .. acs("@w") .. tag
            end
        elseif tag == "(OPK)" then
            if not tagString:match("%s$") then
                tagString = tagString .. " "
            end
            tagString = tagString .. acs("@W(@MOPK@W)")
        elseif tag == "(HARDCORE)" then
            if not tagString:match("%s$") then
                tagString = tagString .. " "
            end
            tagString = tagString .. acs("@W(@RHARDCORE@W)")
        end
        -- Add a space after tags that are not shortflags
        if string.len(tag) > 3 then tagString = tagString .. " " end
    end
    -- If the tagString doesn't end with a space, add one unless the string is empty
    if tagString ~= "" and not tagString:match("%s$") then
        tagString = tagString .. " "
    end
    return tagString
end


function triggerMDBReplace(name, line, wildcards)
    local isCPmob = false
    local isGQmob = false
    local cptag = false

    if line == "{roomchars}" or line == "{/roomchars}" then
        -- This is the start or end of roomchars tag, do not replace
        return line
    end
    local flags = {}
    
    local qmob = false
    local roomname,mobtags = stripMobTags(line)
    if roomname:find("QUEST") then
        -- This is a quest mob, set flag
        qmob = true
        roomname = roomname:gsub(" %[QUEST%]", "") -- Remove the [QUEST] tag for processing
    end
    if roomname:find("CP") then
        -- This is a quest mob, set flag
        cptag = true
        roomname = roomname:gsub(" %[CP%]", "") -- Remove the [QUEST] tag for processing
    end

    
    local foundMatch,level,name,keywords,entry = findMDBMatch(roomname)
    if keywords == nil and foundMatch then
        rune.echo("Mob keywords are missing mob ID: " .. tostring(entry))
        keywords = "None"
    end
    if not foundMatch then
        -- No match found, return the line as is
        local output = reconstituteTags(mobtags) .. acs("@Y") .. roomname
        if qmob then
            output = output .. acs("@R [QUEST]@w")
        end
        if cpflag then
            output = output .. acs("@R [CP]@w")
        end

        if not output:find("%(Player%)") and not output:find("%(P%)") then
            if not table.contains(unclaimedLongNames, roomname) then
                table.insert(unclaimedLongNames, roomname)
            end
        end
        output = output..acs("@w")
        return output
    end
    local displayNames = table.concat(mobdb[entry].names, ",")
    local alreadyKnown = false
    for _, known in ipairs(knownMobsInRoom) do
        if known.id == entry then
            alreadyKnown = true
            break
        end
    end
    if not alreadyKnown then
        table.insert(knownMobsInRoom, {
            id = entry,
            shortname = mobdb[entry].names[1],
            roomname = mobdb[entry].roomname,
            keywords = mobdb[entry].keywords,
            immunities = mobdb[entry].immunities or {}
        })
    end
    -- If it's not a player, send it to the mobtable for the combat plugin
    if not line:find("%(Player%)") and not line:find("%(P%)") then
        -- Add the mob to the mobtable for the combat plugin
        local alignment = "neutral"
        if line:find("%(G%)") or line:find("%(Golden Aura%)") then
            alignment = "good"
        elseif line:find("%(R%)") or line:find("%(Red Aura%)") then
            alignment = "evil"
        end
        
        addtoMobTable(level,name,keywords,alignment)
    end
    -- Add the location to the moblocations table if it doesn't exist
    local roomUID = tostring(room.info.num)
    if not moblocations[entry][roomUID] then
        moblocations[entry][roomUID] = 1
    else
        moblocations[entry][roomUID] = moblocations[entry][roomUID] + 1
    end

    -- Check if the mob name matches one of the CP/GQ targets.
    -- Compare against all known names for this mobdb entry, not just names[1].
    local function matchesAnyMobName(targetName, mobNames)
        if not targetName or targetName == "" or type(mobNames) ~= "table" then return false end
        local targetLower = targetName:lower()
        for _, mobName in ipairs(mobNames) do
            if type(mobName) == "string" and mobName:lower() == targetLower then
                return true
            end
        end
        return false
    end

    local entryNames = (mobdb[entry] and mobdb[entry].names) or {name}
    if cpmobs then
        for _, cpmob in ipairs(cpmobs) do
            if matchesAnyMobName(cpmob.name, entryNames) then
                isCPmob = true
                break
            end
        end
    end
    if gqmobs then
        for _, gqmob in ipairs(gqmobs) do
            if matchesAnyMobName(gqmob.name, entryNames) then
                isGQmob = true
                break
            end
        end
    end
    local output = ""
    if #mobtags > 0 then output = reconstituteTags(mobtags) end
    local mobcolor = "@y"
    if qmob then mobcolor = "@G" end
    if isCPmob then
        mobcolor = "@C"
        setQATarget(keywords,entry)
    elseif isGQmob then
        mobcolor = "@M"
        setQATarget(keywords,entry)
    end

    local levelDisplay = getMobLevelString(mobdb[entry])
    local output = output .. acs("@w[@G" .. levelDisplay .. "@w] " ..
                   mobcolor .. displayNames .. " @y(" .. keywords .. ") @w[" .. entry .. "]")

    if qmob then
        output = output .. acs("@R [QUEST]@w")
        setQATarget(keywords,entry)
    end
    if cptag then
        output = output .. acs("@R [CP]@w")
    end
    output = output .. acs("@w")
    return output
end

local function normalizeMobShortName(shortName)
    if type(shortName) ~= "string" then return nil end
    local normalized = shortName:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    if normalized == "" then return nil end
    return normalized
end

function getMobLevelString(mob)
    if not mob then return "?" end
    if mob.minlevel and mob.maxlevel then
        if mob.minlevel == mob.maxlevel then
            return tostring(mob.minlevel)
        end
        return mob.minlevel .. "-" .. mob.maxlevel
    end
    return tostring(mob.level or "?")
end

function mobLevelOverlaps(mob, checkMin, checkMax)
    if not mob or not checkMin or not checkMax then return false end
    local mobMin, mobMax
    if mob.minlevel and mob.maxlevel then
        mobMin = tonumber(mob.minlevel)
        mobMax = tonumber(mob.maxlevel)
    else
        mobMin = tonumber(mob.level)
        mobMax = mobMin
    end
    if not mobMin or not mobMax then return false end
    return mobMin <= checkMax and mobMax >= checkMin
end

local function recordShortNameSightingForMob(mobID, shortName, roomUID)
    if not mobID or not roomUID then return false end
    local normalized = normalizeMobShortName(shortName)
    if not normalized then return false end

    if not mobnamelocations[mobID] then mobnamelocations[mobID] = {} end
    if not mobnamelocations[mobID][normalized] then mobnamelocations[mobID][normalized] = {} end

    local roomKey = tostring(roomUID)
    mobnamelocations[mobID][normalized][roomKey] = (mobnamelocations[mobID][normalized][roomKey] or 0) + 1
    return true
end

local function resolveMobIDsForShortName(shortName, areaKey)
    local normalized = normalizeMobShortName(shortName)
    if not normalized then return {} end

    local ids = {}
    for mobID, mob in pairs(mobdb) do
        if type(mob) == "table" and type(mob.names) == "table" then
            if areaKey == nil or mob.area == areaKey then
                for _, candidate in ipairs(mob.names) do
                    if normalizeMobShortName(candidate) == normalized then
                        table.insert(ids, mobID)
                        break
                    end
                end
            end
        end
    end
    return ids
end

function recordShortNameSighting(shortName, roomUID)
    if not shortName or not roomUID then return false end

    local areaKey = room.info.zone
    local matches = resolveMobIDsForShortName(shortName, areaKey)
    if #matches == 0 then
        matches = resolveMobIDsForShortName(shortName, nil)
    end
    if #matches ~= 1 then
        return false -- Skip ambiguous matches to avoid polluting room data.
    end

    return recordShortNameSightingForMob(matches[1], shortName, roomUID)
end

local function findBestMobNameMatchInLine(line, areaKey)
    if type(line) ~= "string" or line == "" then return nil, nil end
    local lineLower = line:lower()
    local best = nil
    local ambiguous = false

    for mobID, mob in pairs(mobdb) do
        if type(mob) == "table" and type(mob.names) == "table" and (areaKey == nil or mob.area == areaKey) then
            for _, candidate in ipairs(mob.names) do
                local normalized = normalizeMobShortName(candidate)
                if normalized and lineLower:find(normalized, 1, true) then
                    local len = #normalized
                    if not best or len > best.len then
                        best = { mobID = mobID, shortName = candidate, len = len }
                        ambiguous = false
                    elseif best and len == best.len and (best.mobID ~= mobID or normalizeMobShortName(best.shortName) ~= normalized) then
                        ambiguous = true
                    end
                end
            end
        end
    end

    if best and not ambiguous then
        return best.mobID, best.shortName
    end
    return nil, nil
end

function triggerConsiderLine(name, line, wildcards)
    local raw = wildcards[1] or line
    if not raw or raw == "" then return end
    if raw:find("^%[") then return end -- prompt/status lines

    local roomUID = tostring(room.info.num)
    if not roomUID then return end

    local stripped = select(1, stripMobTags(raw))
    if not stripped or stripped == "" then return end

    local areaKey = room.info.zone
    local mobID, shortName = findBestMobNameMatchInLine(stripped, areaKey)
    if mobID and shortName then
        recordShortNameSightingForMob(mobID, shortName, roomUID)
    end
end

function aliasConsiderTrack(name, line, wildcards)
    local args = wildcards[1] or ""
    rune.trigger.enable("trg_consider_line")
    rune.timer.after(2,function(ctx)
        rune.trigger.disable("trg_consider_line")
    end)
    if args ~= "" then
        rune.send_raw("cons " .. args)
    else
        rune.send_raw("cons")
    end
end

function aliasSmartScan(name, line, wildcards)
    local args = wildcards[1] or ""
    args = args:gsub("^%s+", ""):gsub("%s+$", "")

    if args ~= "" then
        if args:lower() == "all" then
            rune.dbg("Smart scan override: received 'scan all', sending plain 'scan'.")
            rune.send_raw("scan")
            return
        end
        rune.dbg("Smart scan override: passing through explicit scan args: " .. args)
        rune.send_raw("scan " .. args)
        return
    end

    local activity = getActivity()

    if activity == "quest" then
        rune.dbg("Smart scan: activity is quest, sending plain scan.")
        rune.send_raw("scan")
        return
    end

    if smartScanKeywords and smartScanKeywords ~= "" and smartScanKeywords:lower() ~= "none" then
        rune.dbg("Smart scan using current quest/cg/gg target keywords: " .. smartScanKeywords)
        rune.send_raw("scan " .. smartScanKeywords)
        return
    end

    local target = nil
    local targetLabel = nil

    if activity == "gq" and #gqmobs > 0 then
        if gqIndex == 0 then gqIndex = 1 end
        target = gqmobs[gqIndex]
        targetLabel = "GQ"
    elseif activity == "cp" and #cpmobs > 0 then
        if cpIndex == 0 then cpIndex = 1 end
        target = cpmobs[cpIndex]
        targetLabel = "CP"
    end

    if target and type(target.mobIDs) == "table" and #target.mobIDs > 0 then
        local mobID = target.mobIDs[1]
        local mobEntry = mobdb[mobID]
        local keywords = mobEntry and mobEntry.keywords or nil
        if type(keywords) == "string" then
            keywords = keywords:gsub("^%s+", ""):gsub("%s+$", "")
        end

        if keywords and keywords ~= "" and keywords:lower() ~= "none" then
            rune.dbg(string.format("Smart scan using %s target '%s' keywords: %s", targetLabel or "?", tostring(target.name or "?"), keywords))
            rune.send_raw("scan " .. keywords)
            return
        end

        rune.dbg(string.format("Smart scan found %s target '%s' but no usable keywords.", targetLabel or "?", tostring(target.name or "?")))
    else
        rune.dbg("Smart scan has no current GQ/CP target with mobIDs; sending plain scan.")
    end

    rune.send_raw("scan")
end

local function setSmartScanKeywordsFromTarget(target, targetLabel)
    smartScanKeywords = nil
    if type(target) ~= "table" or type(target.mobIDs) ~= "table" or #target.mobIDs == 0 then
        return
    end

    local mobID = target.mobIDs[1]
    local mobEntry = mobdb[mobID]
    local keywords = mobEntry and mobEntry.keywords or nil
    if type(keywords) == "string" then
        keywords = keywords:gsub("^%s+", ""):gsub("%s+$", "")
    end

    if keywords and keywords ~= "" and keywords:lower() ~= "none" then
        smartScanKeywords = keywords
        rune.dbg(string.format("Smart scan target set from %s '%s': %s", targetLabel or "?", tostring(target.name or "?"), smartScanKeywords))
    end
end

local function collectPlanesMobIDsByName(targetName)
    if type(targetName) ~= "string" or targetName == "" then return {} end
    local targetLower = targetName:lower()
    local matches = {}
    for mobID, mob in pairs(mobdb) do
        if type(mob) == "table" and isPlanesArea(mob.area) and type(mob.names) == "table" then
            for _, mobName in ipairs(mob.names) do
                if type(mobName) == "string" and mobName:lower():find(targetLower, 1, true) then
                    table.insert(matches, mobID)
                    break
                end
            end
        end
    end
    return matches
end

function aliasPlanesSearch(name, line, wildcards)
    local query = (wildcards[1] or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local targetName = nil
    local candidateMobIDs = {}

    if #gqmobs > 0 then
        if gqIndex == 0 then gqIndex = 1 end
        targetName = gqmobs[gqIndex].name
        candidateMobIDs = gqmobs[gqIndex].mobIDs or {}
        rune.echo("Planes search: using current GQ mob: " .. tostring(targetName))
    elseif #cpmobs > 0 then
        if cpIndex == 0 then cpIndex = 1 end
        targetName = cpmobs[cpIndex].name
        candidateMobIDs = cpmobs[cpIndex].mobIDs or {}
        rune.echo("Planes search: using current CP mob: " .. tostring(targetName))
    elseif query ~= "" then
        targetName = query
        rune.echo("Planes search: searching for: " .. targetName)
    else
        rune.echo("Usage: planes [mob search string]")
        rune.echo("No active GQ/CP target and no search text provided.")
        return
    end

    local planesMobIDs = collectPlanesMobIDsByName(targetName)

    -- Include already-identified CP/GQ mobIDs that are in planes areas.
    for _, mobID in ipairs(candidateMobIDs) do
        if mobdb[mobID] and isPlanesArea(mobdb[mobID].area) and not table.contains(planesMobIDs, mobID) then
            table.insert(planesMobIDs, mobID)
        end
    end

    if #planesMobIDs == 0 then
        rune.echo("No planes mobs found for: '" .. targetName .. "'")
        return
    end

    rune.echo(string.format("Planes search found %d match(es) for '%s':", #planesMobIDs, targetName))
    for _, mobID in ipairs(planesMobIDs) do
        local mob = mobdb[mobID]
        local nameStr = (mob and mob.names and mob.names[1]) or "Unknown"
        local levelStr = getMobLevelString(mob)
        local areaStr = (mob and mob.area) or "?"
        rune.echo(string.format("  [%d] %s (lvl %s, area %s)", mobID, nameStr, levelStr, tostring(areaStr)))
    end

    for _, mobID in ipairs(planesMobIDs) do
        local poolNum = tonumber(externGetPoolForMob(tostring(mobID)))
        if poolNum then
            rune.echo(string.format("Pool identified: %d (%s)", poolNum, planesPools[poolNum] or "?"))
            rune.send("pool " .. poolNum)
            return
        end
    end

    rune.echo("Could not determine pool from known room sightings yet.")
end

function aliasMobWhere(name, line, wildcards)
    local query = wildcards[2] or ""
    query = query:gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then
        rune.echo("Usage: mobwhere <short name>")
        return false
    end

    local areaKey = room.info.zone
    local matches = resolveMobIDsForShortName(query, areaKey)
    if #matches == 0 then
        matches = resolveMobIDsForShortName(query, nil)
    end

    if #matches == 0 then
        rune.echo("No mobdb entries found with short name: '" .. query .. "'")
        return false
    end

    rune.echo("Short-name location matches for '" .. query .. "' (" .. #matches .. "):")
    rune.echo("ID    | Lvl  | Name                       | Area        | Rooms")
    rune.echo("--------------------------------------------------------------------------")

    for _, mobID in ipairs(matches) do
        local mob = mobdb[mobID]
        local locations = getMobLocationsForShortName(mobID, query)
        local source = "short"
        if #locations == 0 then
            locations = getMobLocations(mobID)
            source = "all"
        end

        local roomStr = "none"
        if #locations > 0 then
            local maxRooms = 8
            local shown = {}
            for i, roomUID in ipairs(locations) do
                if i > maxRooms then break end
                table.insert(shown, tostring(roomUID))
            end
            roomStr = table.concat(shown, "|")
            if #locations > maxRooms then
                roomStr = roomStr .. "|+" .. tostring(#locations - maxRooms)
            end
        end

        local idStr = string.format("%-5d", mobID)
        local lvlStr = string.format("%-4s", getMobLevelString(mob))
        local nameStr = string.format("%-26s", tostring((mob.names and mob.names[1]) or "Unknown"):sub(1, 26))
        local areaStr = string.format("%-11s", tostring(mob.area or "Unknown"):sub(1, 11))
        rune.echo(string.format("%s | %s | %s | %s | %s [%s]", idStr, lvlStr, nameStr, areaStr, roomStr, source))
    end

    return true
end

function getMobLocations(mobID)
    -- Return known locations for mob from moblocations table, sorted by number of sightings
    local locations = {}
    
    -- Check if the mob ID exists in the moblocations table
    if not moblocations[mobID] then
        return locations -- Return empty table if no locations found
    end
    
    -- Extract room UIDs and sight counts into a table for sorting
    local roomsWithCounts = {}
    for roomUID, count in pairs(moblocations[mobID]) do
        table.insert(roomsWithCounts, {roomUID = roomUID, count = count})
    end
    
    -- Sort the locations by number of sightings (highest first)
    table.sort(roomsWithCounts, function(a, b)
        return a.count > b.count
    end)
    
    -- Extract just the roomUIDs in order of frequency
    for _, roomData in ipairs(roomsWithCounts) do
        table.insert(locations, roomData.roomUID)
    end
    
    return locations
end

function getMobLocationsForShortName(mobID, shortName)
    local normalized = normalizeMobShortName(shortName)
    local results = {}
    if not normalized then return results end

    local byName = mobnamelocations[mobID] and mobnamelocations[mobID][normalized]
    if type(byName) ~= "table" then
        return results
    end

    local roomsWithCounts = {}
    for roomUID, count in pairs(byName) do
        table.insert(roomsWithCounts, { roomUID = roomUID, count = count })
    end
    table.sort(roomsWithCounts, function(a, b)
        return a.count > b.count
    end)
    for _, roomData in ipairs(roomsWithCounts) do
        table.insert(results, roomData.roomUID)
    end
    return results
end

function externSearchMobDB(searchStr)
    -- substitute "-name" with "-names" if it exists
    if searchStr:find("-name ") then
        searchStr = searchStr:gsub("-name", "-names")
    end
    
    if searchStr == "next" then
        externalMDBIndex = externalMDBIndex + 1
    elseif not (searchStr:find("^%-") or searchStr:find(" %-")) then
        -- default to names search if no flag provided
        searchStr = "-names '" .. searchStr .."'"
    end

    if searchStr ~= "next" then 
        externalMDBResults = flexibleSearch(mobdb,searchStr)
        externalMDBIndex = 1 -- Reset the index for new search
    end

    -- Only return top result, formatted as a string
    if #externalMDBResults > 0 and #externalMDBResults >= externalMDBIndex then
        local mob = mobdb[externalMDBResults[externalMDBIndex]]
        local locations = getMobLocations(externalMDBResults[externalMDBIndex])
        local locStr = table.concat(locations, ", ")
        if #locations > 3 then
            locStr = locations[1].."," .. locations[2] .. "..." -- Truncate if too long
        end

        return string.format("@G[@C%d/%d@G] Name: @C%s@w | @GArea: @C%s @w| @GRooms: @C%s@w",externalMDBIndex ,#externalMDBResults, mob.names[1], mob.area, locStr)
    else
        return nil -- No results found
    end
end


function aliasMobdbFind(name, line, wildcards)
    local searchStr = wildcards[2]
    if searchStr == "help" then 
        aliasmdbSearchHelp()
        return 0
    end
    -- substitute "-name" with "-names" if it exists
    if searchStr:find("-name ") then
        searchStr = searchStr:gsub("-name", "-names")
    end
    
    if not (searchStr:find("^%-") or searchStr:find(" %-")) then
        -- default to names search if no flag provided
        -- wrap multi-word names in single quotes
        if searchStr:find(" ") and not searchStr:find("^'") then
            searchStr = "'" .. searchStr .. "'"
        end
        searchStr = "-names " .. searchStr
    end

    local results = flexibleSearch(mobdb,searchStr)
    
    -- Display results
    if #results == 0 then
        rune.echo("No mobs found matching '" .. searchStr .. "'")
    else
        rune.echo("Found " .. #results .. " mobs matching '" .. searchStr .. "':")
        rune.echo("ID    | Level | Name                                               | Area        | Locations")
        rune.echo("----------------------------------------------------------------------------------------------------------")
        
        for _, result in ipairs(results) do
           local idStr = string.format("%-5d", result)
           local levelStr = string.format("%-5s", getMobLevelString(mobdb[result]))
           local nameStr = string.format("%-50s", mobdb[result].names[1]:sub(1, 50))
           local areaStr = string.format("%-11s",mobdb[result].area:sub(1, 12))
           local ellipses = ''
           local moblocationsList = getMobLocations(result)
           local locationsStr = table.concat(moblocationsList, ", ")
           if string.len(locationsStr) > 20 then
               locationsStr = locationsStr:sub(1, 20) .. "..."
           end
        --               
        rune.echo(idStr .. " | " ..levelStr .. " | " .. nameStr .. " | " .. areaStr .. " | " .. locationsStr)
        end
    end
    
    return #results
end

function mobdbInfo(name, line, wildcards)
    local mobId = tonumber(wildcards[2])
    
    if not mobId then
        rune.echo("Error: Invalid mob ID. Please provide a numeric ID.")
        return false
    end
    
    local mob = mobdb[mobId]
    
    if not mob then
        rune.echo("Error: No mob found with ID " .. mobId)
        return false
    end
    
    -- Start building detailed output
    rune.echo("-------------------------------------------------------------------")
    rune.echo(" MOB INFORMATION [ID: " .. mobId .. "]")
    rune.echo("-------------------------------------------------------------------")
    
    -- Display all aliases/additional names if available
    for i = 1, #mob.names do
        rune.echo(" Name[" .. i .. "]: " .. mob.names[i])
    end
        
    rune.echo(" Long Name: " .. (mob.roomname or "Unknown"))
    rune.echo(" Keywords: " .. (mob.keywords or "None"))
    rune.echo(" Level: " .. getMobLevelString(mob))
    rune.echo(" Area: " .. (mob.area or "Unknown"))
    
    -- Display any additional information that might be in the mob entry
    if mob.notes then
        rune.echo(" Notes: " .. mob.notes)
    end
    
    -- Display special flags or other attributes
    if mob.flags then
        rune.echo(" Flags: " .. table.concat(mob.flags, ", "))
    end

    if mob.immunities and #mob.immunities > 0 then
        rune.echo(" Immunities: " .. table.concat(mob.immunities, ", "))
    end

    -- Display locations from moblocations table
    local locations = getMobLocations(mobId)
    if #locations > 0 then
        rune.echo(" Locations: " .. table.concat(locations, ", "))
    else
        rune.echo(" Locations: None recorded")
    end

    
    rune.echo("-------------------------------------------------------------------")
    
    return true
end

function mobdbUpdate(name,line,wildcards)
    local mobID = tonumber(wildcards[2])
    local action = wildcards[3]:lower()
    local value = wildcards[4]
    if not mobID or not action or not value then
        rune.echo("Usage: mobdb update <mobID> <action> <value>")
        return false
    end
    if not mobdb[mobID] then
        rune.echo("Error: Mob with ID " .. mobID .. " does not exist.")
        return false
    end
    if action == "keywords" then
        -- Update keywords for the mob
        mobdb[mobID].keywords = value
        rune.echo("Updated keywords for mob ID " .. mobID .. ": " .. value)
    elseif action == "roomname" then
        -- Update roomname for the mob
        mobdb[mobID].roomname = value
        rune.echo("Updated roomname for mob ID " .. mobID .. ": " .. value)
    elseif action == "level" then
        local minL, maxL = value:match("^(%d+)%-(%d+)$")
        if minL and maxL then
            minL = tonumber(minL)
            maxL = tonumber(maxL)
            if minL > maxL then minL, maxL = maxL, minL end
            mobdb[mobID].minlevel = minL
            mobdb[mobID].maxlevel = maxL
            mobdb[mobID].level = nil
            rune.echo("Updated level for mob ID " .. mobID .. ": " .. minL .. "-" .. maxL)
        else
            local levelValue = tonumber(value)
            if not levelValue then
                rune.echo("Error: Level must be a number or range (e.g., 10 or 10-20).")
                return false
            end
            mobdb[mobID].level = levelValue
            mobdb[mobID].minlevel = nil
            mobdb[mobID].maxlevel = nil
            rune.echo("Updated level for mob ID " .. mobID .. ": " .. levelValue)
        end
    elseif action == "minlevel" then
        local levelValue = tonumber(value)
        if not levelValue then
            rune.echo("Error: minlevel must be a number.")
            return false
        end
        mobdb[mobID].minlevel = levelValue
        if not mobdb[mobID].maxlevel then mobdb[mobID].maxlevel = levelValue end
        mobdb[mobID].level = nil
        rune.echo("Updated minlevel for mob ID " .. mobID .. ": " .. levelValue)
    elseif action == "maxlevel" then
        local levelValue = tonumber(value)
        if not levelValue then
            rune.echo("Error: maxlevel must be a number.")
            return false
        end
        mobdb[mobID].maxlevel = levelValue
        if not mobdb[mobID].minlevel then mobdb[mobID].minlevel = levelValue end
        mobdb[mobID].level = nil
        rune.echo("Updated maxlevel for mob ID " .. mobID .. ": " .. levelValue)
    elseif action == "area" then
        -- Update area for the mob
        mobdb[mobID].area = value
        rune.echo("Updated area for mob ID " .. mobID .. ": " .. value)
    elseif action == "notes" then
        -- Update notes for the mob
        mobdb[mobID].notes = value
        rune.echo("Updated notes for mob ID " .. mobID .. ": " .. value)
    elseif action == "addroom" then
        -- Add a room to the mob's locations
        local roomUID = tostring(value)
        if not moblocations[mobID] then moblocations[mobID] = {} end
        if not moblocations[mobID][roomUID] then
            moblocations[mobID][roomUID] = 1
            rune.echo("Added room " .. roomUID .. " to mob ID " .. mobID)
        else
            rune.echo("Room " .. roomUID .. " already exists for mob ID " .. mobID)
        end
    elseif action == "removeroom" then
        -- Remove a room from the mob's locations
        local roomUID = tostring(value)
        if moblocations[mobID] and moblocations[mobID][roomUID] then
            moblocations[mobID][roomUID] = nil
            rune.echo("Removed room " .. roomUID .. " from mob ID " .. mobID)
        else
            rune.echo("Room " .. roomUID .. " not found for mob ID " .. mobID)
        end
    elseif action == "removename" then
        -- Remove a name from the mob's names array
        local indexToRemove = value
        table.remove(mobdb[mobID].names, tonumber(indexToRemove))
        rune.echo("Removed name entry '" .. indexToRemove .. "' from mob ID " .. mobID)    
    elseif action:find("name") and action ~= "addname" then
        -- If action is name, update the first name in the names array
        -- If action is name2, update the second name, etc.
        local nameIndex = tonumber(action:sub(5)) -- Extract the index from the action
        if not nameIndex then nameIndex = 1 end
        if nameIndex and nameIndex > 0 and nameIndex <= #mobdb[mobID].names+1 then
            mobdb[mobID].names[nameIndex] = value
            rune.echo("Updated name[" .. nameIndex .. "] for mob ID " .. mobID .. ": " .. value)
        else
            rune.echo("Invalid name index: " .. nameIndex)
            return false
        end
    elseif action == "addname" then
        -- Add a new name to the mob's names array
        table.insert(mobdb[mobID].names, value)
        rune.echo("Added new name for mob ID " .. mobID .. ": " .. value)
    elseif action == "immunity" then
        local immunityValue = value:lower()
        local validImmunities = {}
        for canonical, _ in pairs(damtypeAliases) do
            validImmunities[canonical] = true
        end
        validImmunities["allphysical"] = true
        validImmunities["allmagical"] = true
        if not mobdb[mobID].immunities then mobdb[mobID].immunities = {} end
        local hasImmunity = table.contains(mobdb[mobID].immunities, immunityValue)
        if hasImmunity then
            for i, imm in ipairs(mobdb[mobID].immunities) do
                if imm == immunityValue then
                    table.remove(mobdb[mobID].immunities, i)
                    break
                end
            end
            rune.echo("Removed immunity '" .. immunityValue .. "' from mob ID " .. mobID)
        else
           if not validImmunities[immunityValue] then
               rune.echo("Invalid immunity type: '" .. value .. "'. Valid types are: " .. table.concat(getTableKeys(validImmunities), ", "))
               return false
           else
               table.insert(mobdb[mobID].immunities, immunityValue)
               rune.echo("Added immunity '" .. immunityValue .. "' to mob ID " .. mobID)
           end
        end
        for _, known in ipairs(knownMobsInRoom) do
            if known.id == mobID then
                known.immunities = mobdb[mobID].immunities
                break
            end
        end
    else
        rune.echo("Unknown action: " .. action)
        return false
    end
    saveMobDBToDisk()
end

function mobdbDelete(name, line, wildcards)
    local mobID = tonumber(wildcards[1])
    
    if not mobID or not mobdb[mobID] then
        rune.echo("Error: Invalid mob ID or mob does not exist.")
        return false
    end
    
    -- Remove the mob from the mobdb
    mobdb[mobID] = nil
    -- Also remove any locations associated with this mob
    moblocations[mobID] = nil
    
    rune.echo("Mob with ID " .. mobID .. " has been deleted from the database.")
    
    return true
end

function mobdbGetLocations(mobName, areaKey)
    -- Validate input
    if not mobName or not areaKey then
        return nil
    end
    
    -- Search for matching mob
    local matchingLocations = {}
    
    for id, mob in pairs(mobdb) do
        -- Check area match first (faster filtering)
        if mob.area and mob.area:lower() == areaKey then
            -- Check for exact name match in any of the mob's names
            if mob.names then
                local foundMatch = false
                for _, name in ipairs(mob.names) do
                    if name:lower() == mobName then
                        foundMatch = true
                        break
                    end
                end
                
                -- If we found a matching mob, collect its locations
                if foundMatch then
                    -- Use moblocations instead of mob.locations
                    for location, _ in pairs(moblocations[id] or {}) do
                        table.insert(matchingLocations, tostring(location))
                    end
                end
            end
        end
    end
    
    -- Return results
    if #matchingLocations > 0 then
        return table.concat(matchingLocations, "|")
    else
        return nil
    end
end

function mobSearchExact(name,area,minlevel,maxlevel)
   if minlevel == nil then minlevel = 1 end
   if maxlevel == nil then maxlevel = 240 end
   if area == nil then area = "none" end

   local results = {}
    for id, mob in pairs(mobdb) do
        for _, mobName in ipairs(mob.names) do
            if mobName:lower() == name:lower() and mobLevelOverlaps(mob, minlevel, maxlevel) then
                if area == "none" then
                    table.insert(results, id)
                elseif mob.area and mob.area:lower() == area:lower() then
                    table.insert(results, id)
                end
            end
        end
    end
    if #results > 0 then
        return results
    else
        return nil
    end
end

function mobdbSearch(name, room, area, minlevel, maxlevel, exact)
    -- Search for mobs by name, room, area, and level range
    -- If exact is true, search only for mobs with exact matches.
    -- If area is provided, it may be a keyword or an exact area name.
    -- If room name is provided, pare down the locations for the mob to those that match the room name.
    -- If mob matches are identified, get locations
    -- We'll return a table of mob IDs and locations
    if minlevel == nil then minlevel = 1 end
    if maxlevel == nil then maxlevel = 240 end
    if exact == nil then exact = false end
    local results = {}
    local areaKeyword = nil
    local roomUIDs = nil
    local mobidMatches = {} -- Will be used to store mob IDs that match the search criteria, will filter down before returning
    -- Ensure we're working with the area keyword, not the name
    if area ~= nil then
        local areaKeyword = findAreaExact(area)
    end
    if room ~= nil then
        -- If a room is specified, find the room UID
        local roomMatches = findRoomExact(room, areaKeyword, nil, nil)
        if roomMatches then
            roomUIDs = string.split(roomMatches, "|") -- Split the room matches into a table
        end
    end
    if area ~= nil and areaKeyword == nil then
        -- If we couldn't find the area keyword, return nil
        return nil, nil, "Error: Area '" .. area .. "' not found."
    end
    if room ~= nil and roomUIDs == nil then
        -- If we couldn't find the room, return nil
        return nil, nil, "Error: Room '" .. room .. "' not found in mapper database."
    end
    for id, mob in pairs(mobdb) do
        if mobLevelOverlaps(mob, minlevel, maxlevel) then
            if area ~= nil and mob.area and mob.area:lower() ~= areaKeyword:lower() then
                goto continue
            end
            -- Check if the mob's names match the search criteria
            for _, mobName in ipairs(mob.names) do
                if exact then
                    if mobName:lower() == name:lower() then
                        table.insert(mobidMatches, id) -- Add mob ID to matches
                    end
                else
                    if mobName:lower():find(name:lower()) then
                        table.insert(mobidMatches, id) -- Add mob ID to matches
                    end
                end
            end
            
        end
    ::continue::
    end

end



function clearQmob()
    -- Clear the quest mob variable
    qmob = nil

end


function findQmobBestRoom(mobname, roomname, areaname)
    -- Narrow down the most likely room for a quest mob, where name, room name, and area name
    -- Try to narrow down the 
    local areakeyword = findAreaExact(areaname)
    rune.dbg("MobDB: Area keyword for area '" .. areaname .. "' is: " .. areakeyword)
    local mobs = mobSearchExact(mobname, areakeyword)
    qmob = mobname -- Cheating a bit, but helps.

    local roomMatches = findRoomExact(roomname, areakeyword, nil, nil)
    rune.dbg("MobDB: Room matches for room '" .. roomname .. "' in area '" .. areaname .. "': " .. (roomMatches or "nil"))

    if not mobs then
        return roomMatches -- No exact matches found
    end
    rune.dbg("MobDB: Found " .. (#mobs or 0) .. " mobs matching '" .. mobname .. "' in area '" .. areaname .. "' with keyword '" .. areakeyword .. "'")

    if roomMatches ~= nil then
        roomMatches = string.split(roomMatches, "|") -- Split the room matches into a table
    end

    for _, mobID in ipairs(mobs) do
        local locations = getMobLocations(mobID)

        for _, roomUID in ipairs(locations) do
            -- Check if the room UID matches the roomMatches
            for _, matchRoom in ipairs(roomMatches) do
                if roomUID == matchRoom then
                    rune.echo("Type for roomUID:  ".. type(roomUID).. " and matchRoom: ".. type(matchRoom))
                    -- We found a match for the quest mob in the specified area and room
                    rune.dbg("MobDB: Found matching room for quest mob: " .. mobname .. " in area: " .. areaname .. " - Room UID: " .. roomUID)
                -- If we found a match, return the mob ID and room UID
                return roomUID
                end
            end
        end
    end
    return nil -- No matching room found for the quest mob
end

function aliasCampaignCheck(name, line, wildcards)
    -- Clear the campaign mobs table and re-capture it
    rune.dbg("Sending campaign check.")
    cpmobs = {}
    cpIndex = 0
    rune.send("tcp")
    rune.send_raw("campaign check")
end

function triggerCampaignComplete(name,line,wildcards)
    rune.pane.clear("cpmobs")
    cpmobs = {}
    cpIndex = 0
    setActivity("cp", false)
    cptype = nil
    smartScanKeywords = nil
end


function aliasGQCheck(name, line, wildcards)
    -- Clear the campaign mobs table and re-capture it
    gqmobs = {}
    gqIndex = 0
    rune.send("tgq")
    rune.send_raw("gq check")
end

function triggerCampaignTarget(name, line, wildcards)
    -- Triggered when a campaign target is set
    local mobName = wildcards[1]
    local location = wildcards[2]
    
    table.insert(cpmobs, {name = mobName, location = location})
end

function triggerGQTarget(name, line, wildcards)
    -- Triggered when a campaign target is set
    local quantity = wildcards[1]
    local mobName = wildcards[2]
    local location = wildcards[3]
    
    table.insert(gqmobs, {name = mobName, location = location, quantity = quantity})
    rune.trigger.enable("trg_gq_check_end") -- Enable the GQ check end trigger
end

function triggerCampaignCheckEnd(name, line, wildcards)
    for i,cpmob in ipairs(cpmobs) do
        if cpmob.location:find(" - Dead$") then
            cpmob.location = cpmob.location:gsub(" %- Dead$", "")
            cpmob.dead = true
        end
    end
    cptype = enhanceMobTargets(cpmobs, false)
    cpmobs = sortCPMobs(cpmobs)

    if #cpmobs > 0 then
        setActivity("cp", true)
    end

    displayCPMobTable()
    renderMinimap()
end

function triggerCampaignStart(name,line,wildcards)
    cpmobs = {}
    cpIndex = 0
    cptype = nil
    setActivity("cp", true)
    rune.send_raw("cp check")
end

function triggerGQCheckEnd(name, line, wildcards)
    rune.trigger.disable("trg_gq_check_end")
    gqtype = enhanceMobTargets(gqmobs, true)
    gqmobs = sortGQMobs(gqmobs)

    if #gqmobs > 0 then
        setActivity("gq", true)
    end

    displayGQMobTable()
end

function enhanceMobTargets(targets, isGQ)
    -- Determine if targets are area-based or room-based
    local targetType = "area" -- Default assumption
    local playerLevel = tonumber(char.base.level) or 1
    
    -- Set level ranges based on whether this is a GQ or CP
    local minLevel, maxLevel
    if isGQ then
        -- GQ level ranges
        minLevel = playerLevel - 18
        maxLevel = playerLevel + 12
        if playerLevel >= 200 then maxLevel = playerLevel + 21 end
    else
        -- CP level ranges
        minLevel = playerLevel - 8
        maxLevel = playerLevel + 16
        if playerLevel >= 200 then maxLevel = playerLevel + 20 end
    end
    
    -- First pass: determine target type (area or room)
    for _, target in ipairs(targets) do
        -- Handle dead targets by removing the "- Dead" suffix
        if target.location:find(" - Dead$") then
            target.location = target.location:gsub(" %- Dead$", "")
            target.dead = true
        end
        
        -- Check if the location is an area
        local areaMatch = findAreaExact(target.location)
        if areaMatch == nil or areaMatch == "" then
            rune.dbg("Target location not found as area: " .. target.location)
            targetType = "room"
            break
        else
            -- Store the area keyword in the target
            target.area = areaMatch
        end
    end
    
    local typeLabel = isGQ and "GQ" or "CP"
    rune.dbg(typeLabel .. " target type determined: " .. targetType)
    
    -- Second pass: enhance each target with mobIDs and roomUIDs
    for i, target in ipairs(targets) do
        target.mobIDs = {}
        target.roomUIDs = {}

        -- DEBUG: Log target details
        rune.dbg("Processing target: " .. target.name .. " in " .. target.location)        

        -- Approach 1: Find exact mob name matches in the appropriate level range
        local exactMatches = mobSearchExact(target.name, targetType == "area" and target.area or nil, minLevel, maxLevel)
        if exactMatches then
            rune.dbg("Found " .. #exactMatches .. " exact mob matches for: " .. target.name)
            for _, mobID in ipairs(exactMatches) do
                table.insert(target.mobIDs, mobID)
                rune.dbg("Mob ID: " .. mobID .. ", Name: " .. (mobdb[mobID].names[1] or "Unknown") .. 
                          ", Level: " .. getMobLevelString(mobdb[mobID]) .. 
                          ", Area: " .. (mobdb[mobID].area or "Unknown"))
                
                -- Add known locations for this mob, preferring this specific short name.
                local mobLocations = getMobLocationsForShortName(mobID, target.name)
                if #mobLocations == 0 then
                    mobLocations = getMobLocations(mobID)
                end
                rune.dbg("Found " .. #mobLocations .. " locations for mob ID: " .. mobID)
                for _, roomUID in ipairs(mobLocations) do
                    -- For area targets, only include rooms in the target area
                    if targetType == "area" then
                        table.insert(target.roomUIDs, roomUID)
                    end
                    -- ...
                end
            end
        end
        
        -- If we didn't find any mob IDs or rooms, try broader search strategies
        if #target.mobIDs == 0 or #target.roomUIDs == 0 then
            if targetType == "area" and target.area then
                for id, mob in pairs(mobdb) do
                    if mob.area == target.area and mobLevelOverlaps(mob, minLevel, maxLevel) then
                        
                        -- Check if any name matches our target name
                        for _, mobName in ipairs(mob.names) do
                            if mobName:lower() == target.name:lower() then
                                -- Add to mobIDs if not already there
                                if not table.contains(target.mobIDs, id) then
                                    table.insert(target.mobIDs, id)
                                    
                                    -- Add locations for this mob, preferring this specific short name.
                                    local mobLocations = getMobLocationsForShortName(id, target.name)
                                    if #mobLocations == 0 then
                                        mobLocations = getMobLocations(id)
                                    end
                                    for _, roomUID in ipairs(mobLocations) do
                                        if not table.contains(target.roomUIDs, roomUID) then
                                            table.insert(target.roomUIDs, roomUID)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            -- For room targets: search for any room with matching name across areas
            if targetType == "room" or #target.roomUIDs == 0 then
                -- Check if we already know the mob's area from earlier matches
                local restrictToArea = nil
                if #target.mobIDs > 0 then
                    -- Get the area of the first matching mob
                    local firstMobID = target.mobIDs[1]
                    if mobdb[firstMobID] and mobdb[firstMobID].area then
                        restrictToArea = mobdb[firstMobID].area
                        rune.dbg("Restricting room search to area: " .. restrictToArea)
                    end
                end

                -- Search for matching rooms, restricted to the mob's area if known
                local roomMatches = findRoomExact(target.location, restrictToArea, nil, nil)
                if roomMatches then
                    rune.dbg("Found room matches for target: " ..target.name.." "..target.location)
                    local roomMatchesTable = string.split(roomMatches, "|")

                    -- If we have mobIDs with known locations, prioritize/intersect
                    if #target.mobIDs > 0 then
                        local mobKnownRooms = {}
                        for _, mobID in ipairs(target.mobIDs) do
                            local mobLocs = getMobLocationsForShortName(mobID, target.name)
                            if #mobLocs == 0 then
                                mobLocs = getMobLocations(mobID)
                            end
                            for _, loc in ipairs(mobLocs) do
                                mobKnownRooms[tostring(loc)] = true
                            end
                        end

                        -- Intersect: rooms matching name AND where mob has been seen
                        local intersected = {}
                        for _, roomUID in ipairs(roomMatchesTable) do
                            if mobKnownRooms[roomUID] then
                                table.insert(intersected, roomUID)
                            end
                        end

                        if #intersected > 0 then
                            -- Use only the intersected rooms
                            for _, roomUID in ipairs(intersected) do
                                if not table.contains(target.roomUIDs, roomUID) then
                                    table.insert(target.roomUIDs, roomUID)
                                end
                            end
                            rune.dbg("Intersected room matches: " .. #intersected .. " rooms")
                        else
                            -- No intersection: put known locations first, then other matches
                            for _, roomUID in ipairs(roomMatchesTable) do
                                if mobKnownRooms[roomUID] and not table.contains(target.roomUIDs, roomUID) then
                                    table.insert(target.roomUIDs, roomUID)
                                end
                            end
                            for _, roomUID in ipairs(roomMatchesTable) do
                                if not mobKnownRooms[roomUID] and not table.contains(target.roomUIDs, roomUID) then
                                    table.insert(target.roomUIDs, roomUID)
                                end
                            end
                            rune.dbg("No intersection, using known locations first")
                        end
                    else
                        -- No mobIDs, just add all room matches
                        for _, roomUID in pairs(roomMatchesTable) do
                            if not table.contains(target.roomUIDs, roomUID) then
                                table.insert(target.roomUIDs, roomUID)
                            end
                        end
                    end
                end
            end
        end
        
        -- Special case: If we found mob IDs but no rooms, check if any rooms match the mob
        if #target.mobIDs > 0 and #target.roomUIDs == 0 then
            for _, mobID in ipairs(target.mobIDs) do
                local mobLocations = getMobLocationsForShortName(mobID, target.name)
                if #mobLocations == 0 then
                    mobLocations = getMobLocations(mobID)
                end
                for _, roomUID in ipairs(mobLocations) do
                    local roomName, roomArea = getRoomDetails(roomUID)
                    
                    -- For area targets, only include rooms in the target area
                    if targetType == "area" and roomArea == target.area then
                        table.insert(target.roomUIDs, roomUID)
                    -- For room targets, check if any room names match
                    elseif targetType == "room" then
                        -- Try finding a room with the right name in any area that matches our mob
                        roomMatches = findRoomExact(target.location, roomArea, nil, playerLevel)
                        if roomMatches then
                            for _, matchUID in pairs(string.split(roomMatches, "|")) do
                                if not table.contains(target.roomUIDs, matchUID) then
                                    table.insert(target.roomUIDs, matchUID)
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Convert roomUIDs to a pipe-delimited string for compatibility
        target.rooms = #target.roomUIDs > 0 and table.concat(target.roomUIDs, "|") or "Unknown"
    end
    
    return targetType
end

-- Sort GQ mobs based on room uniqueness and roomUID
function sortGQMobs(mobs)
    table.sort(mobs, function(a, b)
        -- Check if either mob has unknown rooms
        local aRooms = (a.rooms ~= "Unknown") and string.split(a.rooms, "|") or {}
        local bRooms = (b.rooms ~= "Unknown") and string.split(b.rooms, "|") or {}
        
        -- Priority 1: Mobs with exactly one room (unique mobs) come first
        if #aRooms == 1 and #bRooms ~= 1 then
            return true
        elseif #bRooms == 1 and #aRooms ~= 1 then
            return false
        end
        
        -- Priority 2: Sort by first roomUID (if available)
        local aFirstRoom = #aRooms > 0 and aRooms[1] or "999999" -- Default high value for unknown
        local bFirstRoom = #bRooms > 0 and bRooms[1] or "999999"
        
        -- Try numeric comparison first
        local aNum = tonumber(aFirstRoom)
        local bNum = tonumber(bFirstRoom)
        
        if aNum and bNum then
            return aNum < bNum
        else
            -- Fall back to string comparison if not numeric
            return tostring(aFirstRoom) < tostring(bFirstRoom)
        end
    end)
    
    return mobs
end

-- Sort CP mobs based on first roomUID
function sortCPMobs(mobs)
    table.sort(mobs, function(a, b)
        -- Get room lists
        local aRooms = (a.rooms ~= "Unknown") and string.split(a.rooms, "|") or {}
        local bRooms = (b.rooms ~= "Unknown") and string.split(b.rooms, "|") or {}
        
        -- Get first rooms or use high value for unknown
        local aFirstRoom = #aRooms > 0 and aRooms[1] or "999999"
        local bFirstRoom = #bRooms > 0 and bRooms[1] or "999999"
        
        -- Try numeric comparison first
        local aNum = tonumber(aFirstRoom)
        local bNum = tonumber(bFirstRoom)
        
        if aNum and bNum then
            return aNum < bNum
        else
            -- Fall back to string comparison if not numeric
            return tostring(aFirstRoom) < tostring(bFirstRoom)
        end
    end)
    
    return mobs
end

function aliascpgqht(name, line, wildcards)
    local targetType = 'cp'
    local target = nil
    if name:find("gquest") then targetType = 'gq' end

    if targetType == 'cp' then
        if cpIndex == 0 then cpIndex = 1 end
        target = cpmobs[cpIndex]
    else
        if gqIndex == 0 then gqIndex = 1 end
        target = gqmobs[gqIndex]
    end
    if target == nil then 
        rune.echo("No mob found at index " .. gqIndex)
        return
    end
    if type(target.mobIDs) ~= "table" or #target.mobIDs == 0 then
        rune.echo("No mobdb keyword information found for: " .. target.name)
        return
    end

    -- Use the first mob ID's keywords for the hunt trick
    local mobID = target.mobIDs[1]
    if not mobID then
        rune.echo("No identified mob ID found for: " .. target.name)
        return
    end
    local mobEntry = mobdb[mobID]
    if not mobEntry or not mobEntry.keywords then
        rune.echo("No keywords found for mob ID: " .. tostring(mobID))
        return
    end
    local keywords = mobEntry.keywords
    if keywords and keywords ~= "" then
        rune.send("ht ".. keywords)
    end
end


function displayGQMobTable()
    rune.pane.clear("gqmobs")
    
    for i, gqmob in ipairs(gqmobs) do
        local indexStr = string.format("%s%2d%s","[",i,"]")
        local roomsStr = "Unknown"
        local mobsCount = #(gqmob.mobIDs or {})
        
        -- Handle room display safely
        if gqmob.rooms and gqmob.rooms ~= "Unknown" then
            local gqmobRooms = string.split(gqmob.rooms, "|") -- Split the rooms by pipe
            if #gqmobRooms > 2 then
                -- If there are multiple rooms, show count and first two
                roomsStr = string.format("%s|%s|+%d", gqmobRooms[1], gqmobRooms[2], #gqmobRooms-2)
            elseif #gqmobRooms == 2 then
                roomsStr = gqmobRooms[1] .. "|" .. gqmobRooms[2]
            elseif #gqmobRooms == 1 then
                roomsStr = gqmobRooms[1]
            end
        end
        
        -- Build the display string with mob status indicators
        local locationStr = gqmob.location or "Unknown"
        if gqmob.dead then
            locationStr = locationStr .. " - Dead"
        end
        
        -- Add mob match count indicator if available
        local mobMatchStr = ""
        if mobsCount > 0 then
            mobMatchStr = acs(string.format(" [@Y%s@w]", mobsCount))
        end

        rune.pane.write("gqmobs", acs(string.format("@w%s %s @G%s%s (@w%s@w) @R%s@w",
            indexStr,
            gqmob.quantity or "??",
            gqmob.name,
            mobMatchStr,
            locationStr,
            roomsStr)))
    end
end

function getCPMobs()
    return cpmobs
end

function displayCPMobTable()
    -- TBD - remove return to re-enable
    -- Display the campaign mobs table
    rune.pane.clear("cpmobs") -- Clear the CPGQ window before displaying
    
    for i, cpmob in ipairs(cpmobs) do
        local indexStr = string.format("%s%2d%s","[",i,"]")
        local roomsStr = "Unknown"
        local mobsCount = #(cpmob.mobIDs or {})
        
        -- Handle room display safely
        if cpmob.rooms and cpmob.rooms ~= "Unknown" then
            local cpmobRooms = string.split(cpmob.rooms, "|") -- Split the rooms by pipe
            if #cpmobRooms > 2 then
                -- If there are multiple rooms, show count and first two
                roomsStr = string.format("%s|%s|+%d", cpmobRooms[1], cpmobRooms[2], #cpmobRooms-2)
            elseif #cpmobRooms == 2 then
                roomsStr = cpmobRooms[1] .. "|" .. cpmobRooms[2]
            elseif #cpmobRooms == 1 then
                roomsStr = cpmobRooms[1]
            end
        end
        
        -- Build the display string with mob status indicators
        local locationStr = cpmob.location or "Unknown"
        if cpmob.dead then
            locationStr = locationStr .. " - Dead"
        end
        
        -- Output the formatted line
        rune.pane.write("cpmobs", acs(string.format("@w%s @G%s@w (@w%s@w) @R%s@w",
            indexStr,
            cpmob.name,
            locationStr,
            roomsStr)))
    end
end

function autohuntEnable(name,line,wildcards)
    -- Enable autohunt for the specified mob
    autohuntTarget = wildcards[1]
    if autohuntTarget == "cancel" then
        -- If the target is 'cancel', cancel autohunt
        autohuntCancel(name, line, wildcards)
        return
    end
    rune.dbg("Autohunt enabled for mob: " .. autohuntTarget)
    
    rune.trigger.enable("trg_hunt_output")
    rune.trigger.enable("trg_hunt_output_2")
    rune.trigger.enable("trg_hunt_output_3")
    rune.trigger.enable("trg_hunt_not_found")
    rune.trigger.enable("trg_hunt_is here")
    rune.send_raw("hunt " .. autohuntTarget)
end

function triggerHuntOutput(name,line,wildcards)
    -- Triggered when a hunt output is received and autohunt is enabled
    local direction = wildcards[1]
    rune.send_raw(direction)
    rune.send_raw("hunt " .. autohuntTarget)
end

function autohuntCancel(name,line,wildcards)
    -- Cancel autohunt
    rune.echo("Autohunt cancelled.")
    
    autohuntTarget = nil
    rune.trigger.disable("trg_hunt_output")
    rune.trigger.disable("trg_hunt_output_2")
    rune.trigger.disable("trg_hunt_output_3")
    rune.trigger.disable("trg_hunt_not_found")
    rune.trigger.disable("trg_hunt_is here")
end

function aliasHuntTrick(name, line, wildcards)
    -- Alias for using the hunt trick to find a campaign mob.
    -- Ensure autohunt is disabled
    hunttrickTarget = wildcards[1]
    hunttrickCounter = 1
    rune.trigger.enable("trg_hunttrick_output")
    rune.trigger.enable("trg_hunttrick_output2")
    rune.trigger.enable("trg_hunttrick_output3")
    rune.trigger.enable("trg_hunttrick_not_found")
    rune.trigger.enable("trg_huntrick_is here")
    rune.trigger.enable("trg_hunttrick_unable")
    rune.send_raw("hunt ".. tostring(hunttrickCounter)..".".. hunttrickTarget)
end

function hunttrickNext(name, line, wildcards)
    -- Increment the counter and send the next hunt command
    hunttrickCounter = hunttrickCounter + 1
    rune.send_raw("hunt ".. tostring(hunttrickCounter)..".".. hunttrickTarget)
end

function hunttrickCancel(name, line, wildcards)
    -- Cancel the hunt trick
    rune.echo("Hunt trick cancelled.")
    
    rune.trigger.disable("trg_hunttrick_output")
    rune.trigger.disable("trg_hunttrick_output2")
    rune.trigger.disable("trg_hunttrick_output3")
    rune.trigger.disable("trg_hunttrick_not_found")
    rune.trigger.disable("trg_huntrick_is here")
    rune.trigger.disable("trg_hunttrick_unable")
end

function hunttrickFound(name, line, wildcards)
    -- Cancel the hunt trick
    rune.echo("Target found.")
    
    rune.trigger.disable("trg_hunttrick_output")
    rune.trigger.disable("trg_hunttrick_output2")
    rune.trigger.disable("trg_hunttrick_output3")
    rune.trigger.disable("trg_hunttrick_not_found")
    rune.trigger.disable("trg_huntrick_is here")
    rune.trigger.disable("trg_hunttrick_unable")

    rune.send("where " .. tostring(hunttrickCounter)..".".. hunttrickTarget)
end

function triggerGQJoin(name, line, wildcards)
    gqmobs = {}
    setActivity("gq", true)
end

function mobdbTriggerGQDone(name, line, wildcards)
    gqmobs = {}
    setActivity("gq", false)
    rune.pane.clear("gqmobs")
end

-- Scan functions
function triggerScanStart(name, line, wildcards)
    rune.trigger.enable("trg_scan_mob")
end

function triggerScanEnd(name, line, wildcards)
    rune.trigger.disable("trg_scan_mob")
end

function triggerScanDirection(name, line, wildcards)
    -- Triggered when a scan direction is received
    local direction = wildcards[1]
    local dir = {
        ["North"] = "n",
        ["South"] = "s",
        ["East"] = "e",
        ["West"] = "w",
        ["Up"] = "u",
        ["Down"] = "d"
    }
    if direction == "Right" then scanDirection = nil end

    -- Convert the direction/distance from scan output to a speedwalk
    
    if direction:sub(1,1):match("%d") then
        -- If the first character is a number, it is a speedwalk command
        scanDirection = "run "..direction:sub(1,1) .. dir[direction:sub(3)]
    else
        scanDirection = dir[direction]
    end
end

function triggerScanMob(name,line,wildcards)
    local line = wildcards[1]
    local mobname,mobtags = stripMobTags(line)
    if scanDirection == nil then
        -- "Right here" scan entries can be mapped to current room reliably.
        recordShortNameSighting(mobname, tostring(room.info.num))
        return
    end
    -- If mobname is in the gqmobs or cpmobs table, we'll execute the scanDirection speedwalk
    if qmob ~= nil and mobname:lower() == qmob:lower() then
        -- If this is a quest mob, execute the scan direction
        triggerScanEnd()
        rune.send_raw(scanDirection)
        return
    end

    for _, gqmob in ipairs(gqmobs) do
        if gqmob.name:lower() == mobname:lower() then
            -- If this is a global quest mob, execute the scan direction
            triggerScanEnd()
            rune.send_raw(scanDirection)

            return
        end
    end
    for _, cpmob in ipairs(cpmobs) do
        if cpmob.name:lower() == mobname:lower() then
            -- If this is a campaign mob, execute the scan direction
            triggerScanEnd()
            rune.send_raw(scanDirection)
            return
        end
    end
end

local function runToAreaFromFirstTargetRoom(target, targetLabel)
    if type(target) ~= "table" then return false end
    if type(target.rooms) ~= "string" or target.rooms == "" or target.rooms == "Unknown" then return false end

    local roomUIDs = string.split(target.rooms, "|")
    if not roomUIDs or #roomUIDs == 0 then return false end

    local firstRoom = roomUIDs[1]
    local roomName, roomArea = getRoomDetails(firstRoom)
    if roomArea and roomArea ~= "" then
        rune.echo(string.format("%s target '%s' is room-based; running to area '%s' from room %s.", targetLabel, tostring(target.name or "?"), tostring(roomArea), tostring(firstRoom)))
        rune.send("arun " .. roomArea)
        return true
    end

    return false
end

function campaignGo(name, line, wildcards)
    -- Go to the campaign mob's location
    if charState() ~= "READY" then
        rune.echo("You're too busy to go anywhere right now!")
        return
    end
    local goIndex = wildcards[2]
    if #cpmobs == 0 then
        rune.echo("No campaign mobs found, please run 'campaign check' first.")
        return
    end
    if wildcards[1]:lower() == "r" then
        -- If this is a retry, we need to reset the index to the current cpIndex
        if cpIndex == 0 then cpIndex = 1 end
        goIndex = cpIndex
    elseif wildcards[1]:lower() == "a" or wildcards[1]:lower() == "l" then
        if cpIndex == 0 then cpIndex = 1 end
        -- For a or l, we want to run to the mobs location, as we don't have a good room index
        if cptype == 'area' then
            -- If this is an area type campaign, use arun to go to the area
            rune.send("arun " .. cpmobs[cpIndex].location)
            return
        elseif cptype == 'room' then
            if runToAreaFromFirstTargetRoom(cpmobs[cpIndex], "Campaign") then return end
            rune.echo("No identified room area found for campaign target; falling back to direct room lookup.")
            local roomMatches = findRoomExact(cpmobs[cpIndex].location, room.info.zone, nil, nil)
            if roomMatches then
                local roomUIDs = string.split(roomMatches, "|")
                if #roomUIDs > 0 then
                    rune.send("mapper goto " .. roomUIDs[1])
                    return
                end
            end
            rune.echo("No room found for campaign mob: " .. cpmobs[cpIndex].name .. " in room " .. cpmobs[cpIndex].location .." zone: "..room.info.zone)
            return
        end    
    elseif goIndex ~= nil and goIndex ~= '' then
        -- If passed an index, use it
        cpIndex = tonumber(goIndex)
    else
        -- If no index passed, assume we are going to the next campaign mob
        cpIndex = cpIndex + 1
    end
    if cpIndex > #cpmobs then
        -- If we are at the end of the campaign mobs, reset to the first one
        cpIndex = 1
    end
    rune.echo("Going to campaign mob #" .. cpIndex)
    removeRoomFromCPGQMob(cpIndex,tostring(room.info.num)) -- Remove the current room from the campaign mob list
    --rune.echo("Campaign Mob: " .. cpmobs[cpIndex].name .. " in " .. cpmobs[cpIndex].location .. " with rooms: " .. cpmobs[cpIndex].rooms)

    local cpTarget = cpmobs[cpIndex]
    setSmartScanKeywordsFromTarget(cpTarget, "CP")

    -- Check if this is a planes mob and route via pool alias
    if cpTarget and type(cpTarget.mobIDs) == "table" then
        for _, mobID in ipairs(cpTarget.mobIDs) do
            if mobdb[mobID] and isPlanesArea(mobdb[mobID].area) then
                local poolStr = externGetPoolForMob(tostring(mobID))
                local poolNum = tonumber(poolStr)
                if poolNum then
                    rune.echo(string.format("Campaign mob '%s' is in the planes - going to pool %d (%s)", cpTarget.name, poolNum, planesPools[poolNum] or "?"))
                    rune.send("pool " .. poolNum)
                    return
                else
                    rune.echo(string.format("Campaign mob '%s' is in planes area '%s' but pool unknown. Use: planes", cpTarget.name, mobdb[mobID].area))
                    rune.send("planes")
                    return
                end
            end
        end
    end

    cpRooms = string.split(cpmobs[cpIndex].rooms, "|") -- Get the rooms for the campaign mob at the current index
    -- Much like gowhere, we'll remove rooms as we see them.
    if cpRooms == nil or #cpRooms == 0 then
        rune.echo("No rooms found for campaign mob: " .. cpmobs[cpIndex].name..", you may need to run 'campaign check' again.")
        return
    end
    rune.send("mapper goto " .. cpRooms[1]) -- Go to the first room in the list
end

function gquestGo(name, line, wildcards)
    -- Go to the GQ mob's location
    if charState() ~= "READY" then
        rune.echo("You're too busy to go anywhere right now!")
        return
    end
    local goIndex = wildcards[2]
    if #gqmobs == 0 then
        rune.echo("No campaign mobs found, please run 'campaign check' first.")
        return
    end
    if wildcards[1]:lower() == "r" then
        -- If this is a retry, we need to reset the index to the current gqIndex
        if gqIndex == 0 then gqIndex = 1 end
        goIndex = gqIndex
    elseif wildcards[1]:lower() == "a" or wildcards[1]:lower() == "l" then
        if gqIndex == 0 then gqIndex = 1 end
        -- For a or l, we want to run to the mobs location, as we don't have a good room index
        if gqtype == 'area' then
            -- If this is an area type campaign, use arun to go to the area
            rune.send("arun " .. gqmobs[gqIndex].location)
            return
        elseif gqtype == 'room' then
            if runToAreaFromFirstTargetRoom(gqmobs[gqIndex], "GQ") then return end
            rune.echo("No identified room area found for GQ target; falling back to direct room lookup.")
            local roomMatches = findRoomExact(gqmobs[gqIndex].location, room.info.zone, nil, nil)
            if roomMatches then
                local roomUIDs = string.split(roomMatches, "|")
                if #roomUIDs > 0 then
                    rune.send("mapper goto " .. roomUIDs[1])
                    return
                end
            end
            rune.echo("No room found for GQ mob: " .. gqmobs[gqIndex].name .. " in room " .. gqmobs[gqIndex].location .." zone: "..room.info.zone)
            return
        end    
    elseif goIndex ~= nil and goIndex ~= '' then
        -- If passed an index, use it
        gqIndex = tonumber(goIndex)
    else
        -- If no index passed, assume we are going to the next GQ mob
        gqIndex = gqIndex + 1
    end
    if gqIndex > #gqmobs then
        -- If we are at the end of the campaign mobs, reset to the first one
        gqIndex = 1
    end
    rune.echo("Going to GQ mob #" .. gqIndex)
    removeRoomFromCPGQMob(gqIndex,tostring(room.info.num))
    rune.echo("GQ: " .. gqmobs[gqIndex].name .. " in " .. gqmobs[gqIndex].location .. " with rooms: " .. gqmobs[gqIndex].rooms)

    local gqTarget = gqmobs[gqIndex]
    setSmartScanKeywordsFromTarget(gqTarget, "GQ")

    -- Check if this is a planes mob and route via pool alias
    if gqTarget and type(gqTarget.mobIDs) == "table" then
        for _, mobID in ipairs(gqTarget.mobIDs) do
            if mobdb[mobID] and isPlanesArea(mobdb[mobID].area) then
                local poolStr = externGetPoolForMob(tostring(mobID))
                local poolNum = tonumber(poolStr)
                if poolNum then
                    rune.echo(string.format("GQ mob '%s' is in the planes - going to pool %d (%s)", gqTarget.name, poolNum, planesPools[poolNum] or "?"))
                    rune.send("pool " .. poolNum)
                    return
                else
                    rune.echo(string.format("GQ mob '%s' is in planes area '%s' but pool unknown. Use: planes", gqTarget.name, mobdb[mobID].area))
                    rune.send("planes")
                    return
                end
            end
        end
    end

    gqRooms = string.split(gqmobs[gqIndex].rooms, "|") -- Get the rooms for the GQ mob at the current index
    -- Much like gowhere, we'll remove rooms as we see them.
    if gqRooms == nil or #gqRooms == 0 then
        rune.echo("No rooms found for GQ mob: " .. gqmobs[gqIndex].name..", you may need to run 'gq check' again.")
        return
    end
    rune.send("mapper goto " .. gqRooms[1]) -- Go to the first room in the list
end

function saveMobDBToDisk()
    
    -- Prepare a table with both mobdb and moblocations
    local dataToSave = {
        mobdb = mobdb,
        moblocations = moblocations,
        mobnamelocations = mobnamelocations,
        timestamp = os.time()
    }
    
    -- Serialize the data using CBOR
    local serialized = cbor.encode(dataToSave)
    
    -- Open file for writing in binary mode
    local file, err = io.open(mobdbpath, "wb")
    if not file then
        rune.echo("Error saving mobdb data: " .. (err or "unknown error"))
        return false
    end
    
    -- Write to file and close
    file:write(serialized)
    file:close()
    
    rune.echo("MobDB data saved to " .. mobdbpath)
    rune.echo("Saved " .. #serialized .. " bytes containing " .. 
         table.count(mobdb) .. " mobs with " .. 
         table.count(moblocations) .. " location records")
    
    return true
end

function loadMobDBFromDisk()
    -- Open file for reading in binary mode
    rune.dbg("Attempting to load mobdb data from: " .. mobdbpath)
    local file, err = io.open(mobdbpath, "rb")
    if not file then
        rune.echo("Error opening mobdb data: " .. (err or "unknown error"))
        return false
    end
    
    -- Read all data
    local serialized = file:read("*all")
    file:close()
    
    -- Deserialize data using CBOR
    local success, data = pcall(cbor.decode, serialized)
    if not success or not data then
        rune.echo("Error deserializing mobdb data: " .. (data or "corrupt data"))
        return false
    end
    
    -- Check data structure
    if not data.mobdb or not data.moblocations then
        rune.echo("Invalid mobdb data format")
        return false
    end
    
    -- Update the global tables
    mobdb = data.mobdb
    moblocations = data.moblocations
    mobnamelocations = data.mobnamelocations or {}
    
    rune.echo("MobDB data loaded from " .. mobdbpath)
    rune.echo("Loaded " .. table.count(mobdb) .. " mobs with " .. 
         table.count(moblocations) .. " location records")
    rune.echo("Last saved: " .. os.date("%Y-%m-%d %H:%M:%S", data.timestamp))
    
    return true
end

function mobdbAdd(name,line,wildcards)
    mobdbAddKeywords = wildcards[2]
    if (mobdbAddKeywords == nil or mobdbAddKeywords == "") and (qaDefault ~= nil and qaDefault ~= "") then
        rune.echo("No keywords provided, using qaDefault as keywords: "..qaDefault)
        mobdbAddKeywords = qaDefault
    end
    if mobdbAddKeywords == nil or mobdbAddKeywords == "" then
        rune.echo("No keywords provided and no qaDefault available, cannot proceed.")
        return false
    end
    -- Display a list of unclaimedLongNames to select from
    if #unclaimedLongNames == 0 then
        rune.echo("No unclaimed mobs in this room available.")
        return false
    end
    rune.echo("Select the mob's long name from the list below:")
    for i,roomname in ipairs(unclaimedLongNames) do
        rune.echo("[" .. i .. "] " .. roomname)
    end
    rune.alias.enable("alias_mobadd_select") -- Enable the mobdbAdd select trigger
end

function mobdbAddManual(name, line, wildcards)
    local args = wildcards[2] or ""
    args = args:gsub("^%s+", ""):gsub("%s+$", "")

    if args == "" then
        rune.echo("Usage: ma manual <name>|<keywords>|[roomname]|[level]")
        rune.echo("Example: ma manual giant snake|giant snake|A giant snake slithers.|10-20")
        rune.echo("Fields are pipe-separated. Roomname and level are optional. Level can be a range (10-20).")
        return false
    end

    local parts = string.split(args, "|")
    local mobName = parts[1] and parts[1]:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local keywords = parts[2] and parts[2]:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local roomname = parts[3] and parts[3]:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local levelStr = parts[4] and parts[4]:gsub("^%s+", ""):gsub("%s+$", "") or ""

    if mobName == "" or keywords == "" then
        rune.echo("Error: Name and keywords are required.")
        rune.echo("Usage: ma manual <name>|<keywords>|[roomname]|[level]")
        return false
    end

    local mobId = findFreeID()
    local zone = room.info.zone
    local roomUID = tostring(room.info.num)

    local mobEntry = {
        id = mobId,
        names = {mobName},
        roomname = roomname ~= "" and roomname or "Unknown",
        keywords = keywords,
        level = 0,
        area = zone,
        notes = "Manually added",
        flags = {},
        immunities = {}
    }

    if levelStr ~= "" then
        local minL, maxL = levelStr:match("^(%d+)%-(%d+)$")
        if minL and maxL then
            mobEntry.minlevel = tonumber(minL)
            mobEntry.maxlevel = tonumber(maxL)
            if mobEntry.minlevel > mobEntry.maxlevel then
                mobEntry.minlevel, mobEntry.maxlevel = mobEntry.maxlevel, mobEntry.minlevel
            end
            mobEntry.level = nil
        else
            local lvl = tonumber(levelStr)
            if lvl then mobEntry.level = lvl end
        end
    end

    mobdb[mobId] = mobEntry

    if not moblocations[mobId] then
        moblocations[mobId] = {}
    end
    if roomUID then
        moblocations[mobId][roomUID] = 1
    end

    rune.echo("Manually added mob: " .. mobName .. " (ID: " .. mobId .. ")")
    rune.echo("Use 'mu " .. mobId .. " <field> <value>' to update level, roomname, or other fields.")
    saveMobDBToDisk()
    return true
end

function findFreeID()
    -- Find the next available ID for a new mob, okay with re-using old/freed IDs
    local newId = 1
    while mobdb[newId] do
        newId = newId + 1
    end
    return newId
end


function mobdbAddSelect(name, line, wildcards)
    -- A player will select a number from the list of unclaimedLongNames
    local index = tonumber(wildcards[1])
    if #unclaimedLongNames == 0 then
        -- This should never happen, but just in case
        rune.alias.disable("alias_mobadd_select") -- Disable the alias
        rune.send_raw(wildcards[1]) -- Pass the input along to the MUD as if we didn't do anything
        return false
    end
    
    if not index or index < 1 or index > #unclaimedLongNames then
        rune.echo("Invalid selection. Please select a valid number from the list.")
        return false
    end
    
    local selectedRoomName = unclaimedLongNames[index]
    -- Stash the details we know about the mob so far, we'll need more before we can save it
    --local newMobId = findFreeID()
    newmobInfo = {
        id = newMobId,
        roomname = selectedRoomName,
        keywords = mobdbAddKeywords,
    }
    rune.trigger.enable("trg_last_mob") -- Enable the last mob trigger
    rune.send_raw("lastkills 1")
    return true
end

function triggerLastMob(name,line,wildcards)
    -- Triggered when the last mob is found in the room
    rune.echo("Last mob found: " .. wildcards[1] .. " with level " .. wildcards[2])
    rune.trigger.disable("trg_last_mob") -- Enable the last mob trigger
    local mobName = wildcards[1]
    local level = wildcards[2]
    local zone = room.info.zone
    local roomUID = tostring(room.info.num)
    local mobId = findFreeID() -- Get a new ID for this mob
    
    -- Add the new mob to the mobdb
    mobdb[mobId] = {
        id = mobId,
        names = {mobName},
        roomname = newmobInfo.roomname,
        keywords = newmobInfo.keywords,
        level = level, -- Default level, can be updated later
        area = zone, -- Default area, can be updated later
        notes = "",
        flags = {},
        immunities = {}
    }

    -- Add the location to the moblocations table
    if not moblocations[mobId] then
        moblocations[mobId] = {}
    end
    
    if roomUID then
        moblocations[mobId][roomUID] = 1
    end
    
    rune.echo("Added new mob: " .. mobName .. " with ID: " .. mobId)
    saveMobDBToDisk()
    rune.send("mobdb info " .. mobId) -- Show the mob info after adding it
    return true

end


-- ============================================================
-- External API for other plugins (called via CallPlugin)
-- ============================================================

--- Return current CP target info as "index|name|mobID1|mobID2|..."
function externGetCPInfo()
    if cpIndex == 0 or not cpmobs[cpIndex] then return "" end
    local t = cpmobs[cpIndex]
    local parts = { tostring(cpIndex), t.name or "" }
    for _, id in ipairs(t.mobIDs or {}) do
        table.insert(parts, tostring(id))
    end
    return table.concat(parts, "|")
end

--- Return current GQ target info as "index|name|mobID1|mobID2|..."
function externGetGQInfo()
    if gqIndex == 0 or not gqmobs[gqIndex] then return "" end
    local t = gqmobs[gqIndex]
    local parts = { tostring(gqIndex), t.name or "" }
    for _, id in ipairs(t.mobIDs or {}) do
        table.insert(parts, tostring(id))
    end
    return table.concat(parts, "|")
end

--- Return pipe-delimited room UIDs for a mob ID (for pool detection)
function externGetMobLocations(mobIDStr)
    local mobID = tonumber(mobIDStr)
    if not mobID then return "" end
    local locs = getMobLocations(mobID)
    return table.concat(locs, "|")
end

--- Return the area key for a mob ID
function externGetMobArea(mobIDStr)
    local mobID = tonumber(mobIDStr)
    if not mobID or not mobdb[mobID] then return "" end
    return mobdb[mobID].area or ""
end

--- Search planes-area mobs by name, return pipe-delimited mob IDs
function externPlanesSearch(targetName)
    if not targetName or targetName == "" then return "" end
    local tl = targetName:lower()
    local results = {}
    for id, mob in pairs(mobdb) do
        if isPlanesArea(mob.area) then
            for _, n in ipairs(mob.names or {}) do
                if n:lower():find(tl, 1, true) then
                    table.insert(results, tostring(id))
                    break
                end
            end
        end
    end
    return table.concat(results, "|")
end

--- Return a single-line summary for a mob ID
function externMobSummary(mobIDStr)
    local mobID = tonumber(mobIDStr)
    if not mobID or not mobdb[mobID] then return "Unknown mob " .. tostring(mobIDStr) end
    local mob = mobdb[mobID]
    local locs = getMobLocations(mobID)
    local locStr = #locs > 0 and table.concat(locs, "|") or "none"
    return string.format("[%d] %s (lvl %s, area %s) rooms: %s", mobID, mob.names[1], getMobLevelString(mob), tostring(mob.area), locStr)
end

--- Given a mob ID, return the pool number by checking sighted rooms (or "" if unknown)
function externGetPoolForMob(mobIDStr)
    local mobID = tonumber(mobIDStr)
    if not mobID then return "" end
    local locations = getMobLocations(mobID)
    for _, roomUID in ipairs(locations) do
        local roomName, roomArea = getRoomDetails(roomUID)
        if roomName then
            local pool = getPoolFromRoomName(roomName)
            if pool then return tostring(pool) end
        end
    end
    return ""
end

function removeRoomFromCPGQMob(index, roomUID)
    -- Remove a room from the campaign or GQ mob at the specified index
    if cpmobs[index] then
        local rooms = string.split(cpmobs[index].rooms, "|")
        for i, room in ipairs(rooms) do
            if room == roomUID then
                table.remove(rooms, i)
                cpmobs[index].rooms = table.concat(rooms, "|")
                rune.dbg("Removed room " .. roomUID .. " from campaign mob " .. cpmobs[index].name)
                return true
            end
        end
    elseif gqmobs[index] then
        local rooms = string.split(gqmobs[index].rooms, "|")
        for i, room in ipairs(rooms) do
            if room == roomUID then
                table.remove(rooms, i)
                gqmobs[index].rooms = table.concat(rooms, "|")
                rune.dbg("Removed room " .. roomUID .. " from GQ mob " .. gqmobs[index].name)
                return true
            end
        end
    end
    --rune.echo("Room " .. roomUID .. " not found in campaign/GQ mob at index " .. index)
    return false
end

if not initialized then initializeMobDBPlugin() end
rune.pane.create("gqmobs")
rune.pane.create("cpmobs")
rune.alias.exact("tgq", function()
   layout.setPane("middle", "gqmobs")
end)

require("aardrune/triggers/mobdb_triggers")
require("aardrune/aliases/mobdb_aliases")


rune.alias.exact("tcp", function()
   layout.setPane("middle", "cpmobs")
end)
