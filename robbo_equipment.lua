local cbor = require "aardrune/cbor"
local eqdb = {}
local eqdbpath = rune.config_dir.."/aardrune/data/equipment.dat"
local initialized = false
local lastKnownLevel = nil
local invcontainer = nil
local identifyingItem = nil
local lastIdentifyPart = nil
local identifyData = {}
local desiredeq = {}
local bags = {}
local keydb = {}
local settingPotionType = nil
local settingPotionID = nil
local keydbPendingPuts = {}
local keydbPendingAdds = {}
local shieldup = rune.store.get("shieldup")
local wingsOverride = rune.store.get("wings_override")
local helmOverride = rune.store.get("helm_override")
local wornDataFresh = false
local equippedWeaponDamtype = nil
local equippedSecondWeaponDamtype = nil

if wingsOverride == nil then
    rune.store.set("wings_override", "false")
    wingsOverride = false
elseif wingsOverride == "true" then
    wingsOverride = true
else
    wingsOverride = false
end

if helmOverride == nil then
    rune.store.set("helm_override", "false")
    helmOverride = false
elseif helmOverride == "true" then
    helmOverride = true
else
    helmOverride = false
end

if shieldup == nil then
    rune.store.set("shieldup", "false")
    shieldup = false
elseif shieldup == "true" then
    shieldup = true
else
    shieldup = false
end

local wearable={
[-1] = "none",
[0]="light",
[1]="head",
[2]="eyes",
[3]="lear",
[4]="rear",
[5]="neck1",
[6]="neck2",
[7]="back",
[8]="medal1",
[9]="medal2",
[10]="medal3",
[11]="medal4",
[12]="torso",
[13]="body",
[14]="waist",
[15]="arms",
[16]="lwrist",
[17]="rwrist",
[18]="hands",
[19]="lfinger",
[20]="rfinger",
[21]="legs",
[22]="feet",
[23]="shield",
[24]="wielded",
[25]="second",
[26]="hold",
[27]="float",
[30]="above",
[31]="portal",
[32]="sleeping"}

local eqtype = {
[1]="Light",
[2]="Scroll",
[3]="Wand",
[4]="Stave",
[5]="Weapon",
[6]="Treasure",
[7]="Armor",
[8]="Potion",
[9]="Furniture",
[10]="Trash",
[11]="Container",
[12]="DrinkContainer",
[13]="Key",
[14]="Food",
[15]="Boat",
[16]="MobCorpse",
[17]="PlayerCorpse",
[18]="Fountain",
[19]="Pill",
[20]="Portal",
[21]="Beacon",
[22]="GiftCard",
[23]="Unused",
[24]="RawMaterial",
[25]="Campfire",
[26]="Forge",
[27]="Runestone"}

local invmonActions = {
[1 ] = "Removed (was worn)",
[2 ] = "Worn",
[3 ] = "Removed from inventory (given away, dropped)",
[4 ] = "Added to inventory (received, picked up)",
[5 ] = "Taken out of container",
[6 ] = "Put into container",
[7 ] = "Consumed (quaffed, eaten, rotted)",
[9 ] = "Put into vault",
[10] = "Removed from vault",
[11] = "Put into keyring",
[12] = "Get from keyring"
}

local bloottags = {"((Godly))","(Divine)","(Mythical)","(Fabled)","(Epic)","(Legendary)","(Eternal)","(Exalted)","(Majestic)","(Wondrous)","(Radiant)","(Brilliant)","(Dazzling)","(Shimmering)", "(Gleaming)","(Sparkling)","(Vibrant)","(Shiny)","(Burnished)","(Enhanced)","(Polished)"}


-- Key DB helpers -------------------------------------------------------------
local function normalizeKeyPart(value)
    local v = tostring(value or "")
    v = v:gsub("^%s+", ""):gsub("%s+$", "")
    return v
end

local function getItemFoundArea(item)
    if not item then return nil end
    local area = item.found_at
    area = normalizeKeyPart(area)
    if area == "" then return nil end
    return area
end

local function keySignature(name, area)
    return normalizeKeyPart(name):lower() .. "|" .. normalizeKeyPart(area):lower()
end

local function ensureKeydbShape()
    if type(keydb) ~= "table" then keydb = {} end
    if type(keydb.desired) ~= "table" then keydb.desired = {} end
end

local function hasFlag(item, flagName)
    if not item or not item.flags or not flagName then return false end
    local flags = tostring(item.flags):lower()
    local target = flagName:lower()
    for token in flags:gmatch("[^,]+") do
        local normalizedToken = token:gsub("^%s+", ""):gsub("%s+$", "")
        if normalizedToken == target then
            return true
        end
    end
    return false
end

local function hasSpecial(item, specialName)
    if not item or not item.specials or not specialName then return false end
    local specials = tostring(item.specials):lower()
    local target = specialName:lower()
    for token in specials:gmatch("[^,]+") do
        local normalizedToken = token:gsub("^%s+", ""):gsub("%s+$", "")
        if normalizedToken == target then
            return true
        end
    end
    return false
end

local function hasIsKeyFlag(item)
    return hasFlag(item, "iskey")
end

local function hasHeroOnlyFlag(item)
    return hasFlag(item, "heroonly")
end

local function hasChangingFlag(item)
    return hasSpecial(item, "changing")
end

local function canWearHeroOnlyItem(item)
    if not hasHeroOnlyFlag(item) then return true end
    local actualLevel = tonumber(char.status.level) or 0
    return actualLevel == 200 or actualLevel == 201
end

local function isKeyLikeItem(item)
    if not item then return false end
    -- Items can be key-like by type (Key) or by flag (iskey), independent of their nominal type
    -- Items of type Treasure, Trash, etc. with iskey flag can be placed on the keyring
    if item.type == "Key" then return true end
    if hasIsKeyFlag(item) then return true end
    return false
end

local function getDesiredKeyEntry(name, area)
    ensureKeydbShape()
    return keydb.desired[keySignature(name, area)]
end

local function setDesiredKeyEntry(name, area, level, keywords)
    ensureKeydbShape()
    local sig = keySignature(name, area)
    if not keydb.desired[sig] then
        keydb.desired[sig] = {
            name = normalizeKeyPart(name),
            area = normalizeKeyPart(area),
            level = tonumber(level) or 0,
            keywords = keywords,
            added = os.time(),
            seen = os.time(),
        }
    else
        local entry = keydb.desired[sig]
        entry.level = tonumber(level) or entry.level or 0
        if keywords and keywords ~= "" then entry.keywords = keywords end
        entry.seen = os.time()
    end
    return keydb.desired[sig]
end

local function getKeyItemStateBySignature(signature)
     local state = {
         count = 0,
         keyring = false,
         ids = {},
     }
     for itemID, item in pairs(eqdb) do
         if isKeyLikeItem(item) then
             local area = getItemFoundArea(item) or item.acquiredzone
             local sig = keySignature(item.name, area)
             if sig == signature then
                 state.count = state.count + 1
                 table.insert(state.ids, itemID)
                 if item.keyring then
                     state.keyring = true
                 end
             end
         end
     end
     return state
 end

local function keydbAutoPutForItem(itemID)
     local item = eqdb[itemID]
     if not item or not item.name then return end

     ensureKeydbShape()
     local area = getItemFoundArea(item) or item.acquiredzone or room.info.zone or "Unknown"
     local sig = keySignature(item.name, area)
     local desired = keydb.desired[sig]
     if not desired then return end

     -- Keep the desired key metadata fresh.
     setDesiredKeyEntry(item.name, area, item.level, item.keywords)

     -- Only keep one keyring copy for each desired key.
     local state = getKeyItemStateBySignature(sig)
     if state.keyring then
         keydbPendingPuts[sig] = nil
         return
     end

     if keydbPendingPuts[sig] then
         return
     end

     local keywordCmd = normalizeKeyPart(item.keywords)
     local keyCmd = (keywordCmd ~= "") and keywordCmd or tostring(itemID)
     local isNumericID = tonumber(keyCmd) ~= nil
     rune.dbg("KeyDB: putting desired key on keyring: " .. keyCmd)
     keydbPendingPuts[sig] = true
     if isNumericID then
         rune.send_raw("keyring put " .. keyCmd)
     else
         rune.send_raw("keyring put '" .. keyCmd .. "'")
     end
end

local function finalizeKeydbAddFromItem(itemID, force)
     local item = eqdb[itemID]
     if not item then
         rune.echo("KeyDB: item " .. tostring(itemID) .. " not found.")
         return false
     end
     if not force and not isKeyLikeItem(item) then
         rune.echo("KeyDB: item " .. tostring(itemID) .. " is not key-like after identify.")
         return false
     end

     local area = getItemFoundArea(item)
     if not area then
         rune.echo("KeyDB: item " .. tostring(itemID) .. " is missing found_at area in identify data.")
         return false
     end
     setDesiredKeyEntry(item.name, area, item.level, item.keywords)
     rune.echo("KeyDB: added desired key: [" .. area .. "] " .. item.name)
     saveEQDBToDisk()
     return true
end

local KEYDB_AREA_MIN_WIDTH = 24
local KEYDB_AREA_MAX_WIDTH = 80
local KEYDB_NAME_MIN_WIDTH = 16
local KEYDB_NAME_MAX_WIDTH = 100

local function getDynamicColumnWidth(rows, key, label, minWidth, maxWidth)
    local width = #label
    for _, row in ipairs(rows or {}) do
        local value = normalizeKeyPart(row[key])
        if #value > width then
            width = #value
        end
    end
    if width < minWidth then width = minWidth end
    if width > maxWidth then width = maxWidth end
    return width
end

local function getDynamicAreaColumnWidth(rows)
    return getDynamicColumnWidth(rows, "area", "Area", KEYDB_AREA_MIN_WIDTH, KEYDB_AREA_MAX_WIDTH)
end

local function getDynamicNameColumnWidth(rows)
    return getDynamicColumnWidth(rows, "name", "Name", KEYDB_NAME_MIN_WIDTH, KEYDB_NAME_MAX_WIDTH)
end

local function getIndexColumnWidth(maxIndex)
    local width = #"#"
    local indexText = tostring(tonumber(maxIndex) or 0)
    if #indexText > width then
        width = #indexText
    end
    if width < 2 then width = 2 end
    return width
end

local function hasAnyKeydbNotes(rows)
    for _, row in ipairs(rows or {}) do
        if normalizeKeyPart(row.note) ~= "" then
            return true
        end
    end
    return false
end

local function keydbListHeader(indexWidth, areaWidth, nameWidth)
    return string.format("%-" .. tostring(indexWidth) .. "s", "#") .. " | Lvl | Have | "
        .. string.format("%-" .. tostring(areaWidth) .. "s", "Area") .. " | "
        .. string.format("%-" .. tostring(nameWidth) .. "s", "Name")
end

local function keydbListSeparatorLength(header, rows)
    local len = #header
    if hasAnyKeydbNotes(rows) then
        len = len + 7 -- space + [Note]
    end
    return len
end

local function keydbAddnameHeader(areaWidth, nameWidth)
    return " ID         | Lvl | " .. string.format("%-" .. tostring(areaWidth) .. "s", "Area") .. " | "
        .. string.format("%-" .. tostring(nameWidth) .. "s", "Name")
end

local function keydbMissingReport(showAllLevels)
    ensureKeydbShape()
    local playerLevel = tonumber(char.status.level) or 1
    local levelWindow = 15
    local allRows = {}
    for sig, desired in pairs(keydb.desired) do
        local state = getKeyItemStateBySignature(sig)
        table.insert(allRows, {
            sig = sig,
            level = tonumber(desired.level) or 0,
            area = desired.area,
            name = desired.name,
            have = state.keyring and "yes" or "no",
            note = desired.note,
        })
    end

    table.sort(allRows, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        if a.area ~= b.area then return a.area < b.area end
        return a.name < b.name
    end)

    local missing = {}
    for idx, row in ipairs(allRows) do
        local inRange = showAllLevels or row.level == 0 or math.abs(row.level - playerLevel) <= levelWindow
        if inRange and row.have ~= "yes" then
            table.insert(missing, { index = idx, row = row })
        end
    end

    local missingRowsOnly = {}
    for _, m in ipairs(missing) do
        table.insert(missingRowsOnly, m.row)
    end
    local areaWidth = getDynamicAreaColumnWidth(missingRowsOnly)
    local nameWidth = getDynamicNameColumnWidth(missingRowsOnly)
    local indexWidth = getIndexColumnWidth(#allRows)

    if #missing == 0 then
        if showAllLevels then
            rune.echo("KeyDB: No missing tracked keys.")
        else
            rune.echo("KeyDB: No missing tracked keys within +/- " .. levelWindow .. " levels of level " .. playerLevel .. ".")
        end
        return
    end

    if showAllLevels then
        rune.echo(acs("@cKeyDB Missing Keys (all levels):"))
    else
        rune.echo(acs("@cKeyDB Missing Keys (level " .. playerLevel .. " +/- " .. levelWindow .. "):"))
    end
    local header = keydbListHeader(indexWidth, areaWidth, nameWidth)
    rune.echo(acs("@D" .. header))
    rune.echo(acs("@D" .. string.rep("-", keydbListSeparatorLength(header, missingRowsOnly))))
    for _, m in ipairs(missing) do
        local idx = m.index
        local r = m.row
        local area = r.area or "Unknown"
        local name = r.name or "Unknown"
        local haveColor = r.have == "yes" and "@G" or "@R"

        rune.echo(acs("@Y" .. string.format("%" .. tostring(indexWidth) .. "d", idx)))
        rune.echo(acs("@D | "))
        rune.echo(acs("@w" .. string.format("%3d", r.level)))
        rune.echo(acs("@D | "))
        rune.echo(acs(haveColor .. string.format("%-4s", r.have)))
        rune.echo(acs("@D | "))
        rune.echo(acs("@D" .. string.format("%-" .. tostring(areaWidth) .. "s", area)))
        rune.echo(acs("@D | "))
        rune.echo(acs("@w" .. string.format("%-" .. tostring(nameWidth) .. "s", name)))

        if normalizeKeyPart(r.note) ~= "" then
            rune.echo(acs("@D "))
            local ok = pcall(Hyperlink, "kdb note " .. tostring(idx),"[Note]", "Show key note", "deepskyblue", "black")
            if not ok then
                rune.echo(acs("@C[Note]"))
            end
        end

        rune.echo("")
    end
end

local function getDesiredKeyRowsSorted()
    ensureKeydbShape()
    local rows = {}
    for sig, desired in pairs(keydb.desired) do
        local state = getKeyItemStateBySignature(sig)
        table.insert(rows, {
            sig = sig,
            level = tonumber(desired.level) or 0,
            area = desired.area,
            name = desired.name,
            have = state.keyring and "yes" or "no",
            note = desired.note,
        })
    end

    table.sort(rows, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        if a.area ~= b.area then return a.area < b.area end
        return a.name < b.name
    end)

    return rows
end

local function hasDesiredKeyNote(noteText)
    return normalizeKeyPart(noteText) ~= ""
end

local function printKeydbListRow(index, row, indexWidth, areaWidth, nameWidth)
    local area = row.area or "Unknown"
    local name = row.name or "Unknown"
    local haveColor = row.have == "yes" and "@G" or "@R"

    rune.echo(acs("@Y" .. string.format("%" .. tostring(indexWidth) .. "d", index)))
    rune.echo(acs("@D | "))
    rune.echo(acs("@w" .. string.format("%3d", row.level)))
    rune.echo(acs("@D | "))
    rune.echo(acs(haveColor .. string.format("%-4s", row.have)))
    rune.echo(acs("@D | "))
    rune.echo(acs("@D" .. string.format("%-" .. tostring(areaWidth) .. "s", area)))
    rune.echo(acs("@D | "))
    rune.echo(acs("@w" .. string.format("%-" .. tostring(nameWidth) .. "s", name)))

    if hasDesiredKeyNote(row.note) then
        rune.echo(acs("@D "))
        local ok = pcall(Hyperlink, "kdb note " .. tostring(index),"[Note]", "Show key note", "deepskyblue", "black")
        if not ok then
            rune.echo(acs("@C[Note]"))
        end
    end

    rune.echo("")
end

function aliasKeyDB(name, line, wildcards)
    ensureKeydbShape()
    local args = wildcards[1] and wildcards[1]:split(" ") or {}
    local action = args[1] and args[1]:lower() or "missing"

    if action == "add" then
        local itemID = tonumber(args[2] or "")
        if not itemID or not eqdb[itemID] then
            rune.echo("Usage: keydb add <item_id>")
            return
        end
        local item = eqdb[itemID]
        -- When adding by explicit ID we trust the player knows what they want,
        -- so we skip the key-like check. If the item is unidentified we still
        -- run identify first so flags/name are populated before storing.
        if item.identified == false or not getItemFoundArea(item) then
            keydbPendingAdds[itemID] = true
            rune.echo("KeyDB: item " .. itemID .. " needs identify data (found_at); identifying now...")
            rune.send_raw("identify " .. itemID)
            return
        end
        finalizeKeydbAddFromItem(itemID, true)
        return
    elseif action == "addname" then
        local query = ""
        if #args >= 2 then
            query = table.concat(args, " ", 2)
        end
        query = normalizeKeyPart(query)
        if query == "" then
            rune.echo("Usage: keydb addname <partial_key_name>")
            return
        end

        local bySignature = {}
        for itemID, item in pairs(eqdb) do
            local nameMatch = item.name and item.name:lower():find(query:lower(), 1, true)
            local keywordMatch = item.keywords and item.keywords:lower():find(query:lower(), 1, true)
            local unresolvedCandidate = (item.identified == false) or (getItemFoundArea(item) == nil)
            if (nameMatch or keywordMatch) and (isKeyLikeItem(item) or unresolvedCandidate) then
                local area = getItemFoundArea(item) or item.acquiredzone or room.info.zone or "Unknown"
                local sig = keySignature(item.name, area)
                if not bySignature[sig] then
                    bySignature[sig] = {
                        id = itemID,
                        name = item.name,
                        area = area,
                        level = tonumber(item.level) or 0,
                        keywords = item.keywords,
                    }
                end
            end
        end

        local matches = {}
        for _, row in pairs(bySignature) do
            table.insert(matches, row)
        end
        table.sort(matches, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            if a.area ~= b.area then return a.area < b.area end
            return a.name < b.name
        end)

        if #matches == 0 then
            rune.echo("KeyDB: no key matches found for '" .. query .. "'.")
            return
        elseif #matches == 1 then
            local m = matches[1]
            local item = eqdb[m.id]
            if item and ((not isKeyLikeItem(item) and item.identified == false) or not getItemFoundArea(item)) then
                keydbPendingAdds[m.id] = true
                rune.echo("KeyDB: matched item needs identify data (found_at); identifying now...")
                rune.send_raw("identify " .. m.id)
                return
            end
            finalizeKeydbAddFromItem(m.id)
            return
        end

        rune.echo("KeyDB: multiple keys match '" .. query .. "'. Use keydb add <item_id> to choose one:")
        local areaWidth = getDynamicAreaColumnWidth(matches)
        local nameWidth = getDynamicNameColumnWidth(matches)
        local header = keydbAddnameHeader(areaWidth, nameWidth)
        rune.echo(header)
        rune.echo(string.rep("-", #header))
        for _, m in ipairs(matches) do
            rune.echo(string.format("%-11d | %3d | %-" .. tostring(areaWidth) .. "s | %-" .. tostring(nameWidth) .. "s", m.id, m.level, m.area or "Unknown", m.name or "Unknown"))
        end
        return
    elseif action == "delete" or action == "del" or action == "remove" then
        local index = tonumber(args[2] or "")
        if not index then
            rune.echo("Usage: keydb delete <index>")
            return
        end

        local rows = getDesiredKeyRowsSorted()
        local row = rows[index]
        if not row then
            rune.echo("KeyDB: index out of range (1-" .. tostring(#rows) .. ").")
            return
        end

        keydb.desired[row.sig] = nil
        rune.echo("KeyDB: removed desired key #" .. tostring(index) .. ": [" .. (row.area or "Unknown") .. "] " .. (row.name or "Unknown"))
        saveEQDBToDisk()
        return
    elseif action == "note" then
        local index = tonumber(args[2] or "")
        if not index then
            rune.echo("Usage: keydb note <index> [clear|text...]")
            return
        end

        local rows = getDesiredKeyRowsSorted()
        local row = rows[index]
        if not row then
            rune.echo("KeyDB: index out of range (1-" .. tostring(#rows) .. ").")
            return
        end

        local entry = keydb.desired[row.sig]
        if not entry then
            rune.echo("KeyDB: key entry no longer exists for index " .. tostring(index) .. ".")
            return
        end

        if #args == 2 then
            local existing = normalizeKeyPart(entry.note)
            if existing == "" then
                rune.echo("KeyDB note #" .. tostring(index) .. " (" .. (entry.name or "Unknown") .. "): <none>")
            else
                rune.echo("KeyDB note #" .. tostring(index) .. " (" .. (entry.name or "Unknown") .. "): " .. existing)
            end
            return
        end

        if args[3] and args[3]:lower() == "clear" and #args == 3 then
            entry.note = nil
            entry.seen = os.time()
            saveEQDBToDisk()
            rune.echo("KeyDB: cleared note for #" .. tostring(index) .. " (" .. (entry.name or "Unknown") .. ").")
            return
        end

        local noteText = normalizeKeyPart(table.concat(args, " ", 3))
        if noteText == "" then
            rune.echo("Usage: keydb note <index> [clear|text...]")
            return
        end

        entry.note = noteText
        entry.seen = os.time()
        saveEQDBToDisk()
        rune.echo("KeyDB: set note for #" .. tostring(index) .. " (" .. (entry.name or "Unknown") .. ").")
        return
    elseif action == "list" or action == "all" then
        local rows = getDesiredKeyRowsSorted()
        if #rows == 0 then
            rune.echo("KeyDB: no desired keys configured.")
            return
        end
        local areaWidth = getDynamicAreaColumnWidth(rows)
        local nameWidth = getDynamicNameColumnWidth(rows)
        local indexWidth = getIndexColumnWidth(#rows)
        local header = keydbListHeader(indexWidth, areaWidth, nameWidth)
        rune.echo(acs("@cKeyDB Desired Keys:"))
        rune.echo(acs("@D" .. header))
        rune.echo(acs("@D" .. string.rep("-", keydbListSeparatorLength(header, rows))))
        for idx, r in ipairs(rows) do
            printKeydbListRow(idx, r, indexWidth, areaWidth, nameWidth)
        end
        return
    elseif action == "sync" or action == "put" then
        keydbSync()
        return
    elseif action == "missing" then
        keydbMissingReport(false)
        return
    elseif action == "missingall" then
        keydbMissingReport(true)
        return
    else
        rune.echo("Usage: keydb <add|addname|delete|note|list|missing|missingall|sync> [args]")
        return
    end
end

function aliasKList(name, line, wildcards)
    aliasKeyDB(name, "kdb list", {"list"})
end

function keydbSync(name, line, wildcards)
     ensureKeydbShape()
     local count = 0
     for itemID, item in pairs(eqdb) do
         if not item.keyring and item.name then
             -- Only match items that are key-like: type is Key, has iskey flag, or were explicitly added by ID.
             -- iskey-flagged Treasure items are treated as keys, along with standard Key-type items.
             if isKeyLikeItem(item) then
                  local area = getItemFoundArea(item) or item.acquiredzone or ""
                 local sig = keySignature(item.name, area)
                 if keydb.desired[sig] then
                     -- Check we don't already have one on the keyring.
                     local state = getKeyItemStateBySignature(sig)
                     if not state.keyring and not keydbPendingPuts[sig] then
                         local keywordCmd = normalizeKeyPart(item.keywords)
                         local keyCmd = (keywordCmd ~= "") and keywordCmd or tostring(itemID)
                         local isNumericID = tonumber(keyCmd) ~= nil
                         rune.dbg("KeyDB sync: putting key on keyring: " .. keyCmd)
                         keydbPendingPuts[sig] = true
                         if isNumericID then
                             rune.send_raw("keyring put " .. keyCmd)
                         else
                             rune.send_raw("keyring put '" .. keyCmd .. "'")
                         end
                         count = count + 1
                     end
                 end
             end
         end
     end
     if count > 0 then
         rune.echo("KeyDB: queued " .. count .. " key(s) for keyring.")
     else
         rune.echo("KeyDB: all desired keys already on keyring (or none available in inventory).")
     end
end


function initializeEQPlugin()
    -- Load serialized data from disk.
    loadEQDBFromDisk()
    rune.timer.every(120,function(ctx)
       saveEQDBToDisk()
    end )
    initialized = true
end

function refreshEquippedWeaponDamtype()
    equippedWeaponDamtype = nil
    equippedSecondWeaponDamtype = nil
    for itemId, itemData in pairs(eqdb) do
        if itemData.wornloc == "wielded" and itemData.damtype then
            equippedWeaponDamtype = normalizeDamtype(itemData.damtype)
        elseif itemData.wornloc == "second" and itemData.damtype then
            equippedSecondWeaponDamtype = normalizeDamtype(itemData.damtype)
        end
    end
end

function getEquippedWeaponDamtype()
    return equippedWeaponDamtype
end

function getEquippedSecondWeaponDamtype()
    return equippedSecondWeaponDamtype
end

function saveEQDBToDisk()
    -- Prepare a table with both mobdb and moblocations
    local dataToSave = {
        eqdb = eqdb,
        desiredeq = desiredeq,
        bags = bags,
        keydb = keydb,
        timestamp = os.time()
    }
    
    -- Serialize the data using CBOR
    local serialized = cbor.encode(dataToSave)
    
    -- Open file for writing in binary mode
    local file, err = io.open(eqdbpath, "wb")
    if not file then
        rune.echo("Error saving equipment data: " .. (err or "unknown error"))
        return false
    end
    
    -- Write to file and close
    file:write(serialized)
    file:close()
    
    if charState() == "READY" then
        -- Less spam if the player is busy.
        rune.echo("Saved EQ Data: Stored " .. #serialized .. " bytes containing " .. table.count(eqdb) .. " equipment records")
    end
    
    return true
end

function aliasEquipmentHelp(name, line, wildcards)
    helpHeader("Equipment Commands")
    helpRule()

    helpSection("Inventory Database")
    helpCmd("invupdate [detail]",                 "Refresh inventory from MUD. IDs weapons/armor not currently identified")
    helpCmd("invupdate detail all",               "Time consuming! IDs all items not currently identified")
    helpCmd("invsearch <filters>",                "Search equipment database. See 'invsearch help'")
    helpCmd("invcount <filters>",                 "Count items matching filters")
    helpCmd("iteminfo <item_id>",                 "Show all stored fields for an item")
    rune.echo("")

    helpSection("Desired Equipment")
    helpCmd("equipforlevel [level]",              "Equip desired setup for level (defaults to current level)")
    helpCmd("showeq <wear location>",             "Show registered equipment for a specific wear location")
    helpCmd("addeq <item_id> <location> [level]", "Add desired item for slot/level")
    helpCmd("deleq <item_id>",                    "Delete saved set at level")
    helpCmd("saveeqset",                          "Save currently worn setup into desired table")
    helpCmd("dumpdesiredeq",                      "Show chosen desired equipment for current level")
    helpCmd("shieldup",                           "Enable shield mode")
    helpCmd("dual",                               "Enable dual-wield mode")
    helpCmd("dt <damtype>",                       "Equip highest level weapon with damage type")
    helpCmd("wings <on|off>",                     "Override back slot with Wings of Aardwolf")
    helpCmd("helm <on|off>",                      "Override head slot with best Aardwolf Helm of True Sight <= level")
    rune.echo("")

    helpSection("Potions / Utility")
    helpCmd("healpot|manapot|movepot <keyword>",  "Register potion by type using keyword. ")
    helpCmd("qheal|qmana|qmove>",                 "Quaff configured potion type")
    helpCmd("transport <item_id|keywords>",       "Use a portal from inventory/container")
    rune.echo("")

    helpSection("Help")
    helpCmd("eq help",                             "Show this command help")
    helpCmd("invsearch help",                      "Show search filter syntax/examples")
    helpCmd("keydb addname <text>",                "Add desired key by partial name (asks to disambiguate if needed)")
    helpCmd("keydb delete <index>",                "Delete desired key by index shown in keydb list")
    helpCmd("keydb note <index> [clear|text]",     "View/set/clear per-key note")
    helpCmd("klist",                               "Shortcut for keydb list")
    helpCmd("keydb <subcommand>",                  "Manage desired keys (add/addname/delete/note/list/missing/sync)")

    helpRule()
end

function invSearchHelp(name, line, wildcards)
    helpHeader("Equipment Search Help")
    helpRule()

    helpSection("Basic Usage")
    helpCmd("invsearch -field value [-field value...]", "Find matching items")
    helpCmd("invcount -field value [-field value...]",  "Count matches only")
    helpCmd("Quotes",                                   "Use single/double quotes for multi-word values")
    rune.echo("")

    helpSection("Common Fields")
    helpCmd("-name <text>",           "Item name contains text (case-insensitive)")
    helpCmd("-type <type>",           "Item type (Weapon, Armor, Portal, Potion, ...)")
    helpCmd("-level <n|a-b>",         "Exact level or range (e.g. 90 or 80-100)")
    helpCmd("-wornloc <slot>",        "Wear location (head, wielded, shield, portal, ...)")
    helpCmd("-identified <bool>",     "true/false, yes/no, 1/0")
    helpCmd("-vaulted <bool>",        "true/false, yes/no, 1/0")
    helpCmd("-keyring <bool>",        "true/false, yes/no, 1/0")
    helpCmd("-container <id>",        "Container id currently holding item")
    helpCmd("-keywords <text>",       "Identify keywords contains text")
    helpCmd("-damtype <type>",        "Damage type; supports equivalent subtype mapping")
    rune.echo("")

    helpSection("Damage Type Mapping")
    helpCmd("-damtype acid",          "Matches acid, acidic bite, digestion, slime")
    helpCmd("-damtype bash",          "Matches beating/blast/charge/crush/hit/... etc")
    helpCmd("-damtype pierce",        "Matches bite/chomp/peck/pierce/scratch/stab/sting/thrust")
    helpCmd("-damtype slash",         "Matches chop/claw/cleave/grep/slash/slice/whip")
    helpCmd("Subtype query",          "You can also search by subtype (e.g. -damtype slime)")
    rune.echo("")

    helpSection("Examples")
    helpCmd("invsearch -type Weapon -level 175-201",              "Weapons in level range")
    helpCmd("invsearch -type Portal -identified false",           "Unidentified portals")
    helpCmd("invsearch -name 'obsidian' -wornloc wielded",        "Name + slot filter")
    helpCmd("invsearch -damtype fire -type Weapon",               "Weapons with fire-equivalent damtype")
    helpCmd("invcount -type Potion -name 'restore'",              "Count matching potions")

    helpRule()
end

function loadEQDBFromDisk()
    -- Open file for reading in binary mode
    local file, err = io.open(eqdbpath, "rb")
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
        rune.echo("Error deserializing equipment data: " .. (data or "corrupt data"))
        return false
    end
    
    -- Check data structure
    if not data.eqdb  then
        rune.echo("Invalid equipment data format")
        return false
    end
    
    -- Update the global tables
    eqdb = data.eqdb or {}
    desiredeq = data.desiredeq or {}
    bags = data.bags or {}
    keydb = data.keydb or {}
    wornDataFresh = false

    rune.echo("Equipment data loaded from " .. eqdbpath)
    rune.echo("Loaded " .. table.count(eqdb) .. " equipment records")
    rune.echo("Last saved: " .. os.date("%Y-%m-%d %H:%M:%S", data.timestamp))
    
    return true
end

function aliasUpdateInventory(name,line,wildcards)
    -- Get all inventory data
    rune.dbg("Updating inventory data...")
    -- First, let's set an seen flag on all non-vaulted items. If we don't
    -- see them in the update, we'll delete them.
    for itemID, itemData in pairs(eqdb) do
        if not itemData.vaulted then
            itemData.seen = false
        end
    end

    rune.send_raw("keyring get all")
    rune.send_raw("eqdata ansi")
    rune.send_raw("invdata ansi")
    rune.send_raw("keyring put all")
    rune.dbg("Setting timer to update container inventory")
    rune.timer.after(1, function(ctx)
       updateContainerInventory()
    end)
    rune.timer.after(10, function(ctx)
       purgeUnaccountedInventory()
    end)
    rune.timer.after(16, function(ctx)
       saveEQDBToDisk()
    end)
end

-- Display the desired equipment for a specific wearable location
function displayDesiredEQ(name, line, wildcards)
    local location = wildcards[1]
    
    -- Check if location is valid
    if not location or not table.contains(wearable, location) then
        rune.echo("Invalid location. Valid locations are:")
        local validLocs = {}
        for _, loc in pairs(wearable) do
            if loc ~= "none" and loc ~= "sleeping" then
                table.insert(validLocs, loc)
            end
        end
        table.sort(validLocs)
        rune.echo(table.concat(validLocs, ", "))
        return
    end
    
    -- Check if there's any equipment for this location
    if not desiredeq[location] or next(desiredeq[location]) == nil then
        rune.echo("No desired equipment set for location: " .. location)
        return
    end
    
    -- Get all level keys and sort them
    local levels = {}
    for level, _ in pairs(desiredeq[location]) do
        table.insert(levels, level)
    end
    table.sort(levels)
    
    -- Display the equipment
    rune.echo("Desired equipment for " .. location .. ":")
    rune.echo("Level | Item ID     | Name")
    rune.echo("------------------------------------------------------------------")
    
    for _, level in ipairs(levels) do
        local itemID = desiredeq[location][level]
        local itemName = eqdb[itemID] and eqdb[itemID].name or "Unknown (item not in database)"
        rune.echo(string.format("%-5d | %-11d | %s", level, itemID, itemName))
    end
end

-- Remove an item from desired equipment by ID
function removeDesiredEQ(name, line, wildcards)
    local itemID = tonumber(wildcards[1])
    if not itemID then
        rune.echo("Usage: eqremove <item_id>")
        return
    end
    
    -- Search through all locations and levels to find and remove the item
    local found = false
    for location, levels in pairs(desiredeq) do
        for level, id in pairs(levels) do
            if id == itemID then
                desiredeq[location][level] = nil
                rune.echo("Removed item " .. itemID .. " from " .. location .. " at level " .. level)
                found = true
                -- Don't break, in case the same item is used in multiple slots/levels
            end
        end
        
        -- If the location has no more items, remove the empty table
        if next(desiredeq[location]) == nil then
            desiredeq[location] = nil
        end
    end
    
    if not found then
        rune.echo("Item " .. itemID .. " not found in desired equipment list.")
    else
        -- Save changes
        saveEQDBToDisk()
    end
end

-- Add an item to desired equipment
function addDesiredEQ(name, line, wildcards)
    local itemID = tonumber(wildcards[1])
    local location = wildcards[2]
    local level = tonumber(wildcards[3])
    
    -- Validate inputs
    if not itemID or not location then
        rune.echo("Usage: eqadd <item_id> <location> [level]")
        return
    end
    
    -- Check if item exists in eqdb
    if not eqdb[itemID] then
        rune.echo("Error: Item " .. itemID .. " not found in equipment database.")
        return
    end
    
    -- If level not provided, use the item's level
    if not level then
        level = eqdb[itemID].level
        if not level then
            rune.echo("Error: Item has no level defined. Please specify a level.")
            return
        end
    end
    
    -- Check if location is valid
    if not table.contains(wearable, location) then
        rune.echo("Invalid location: " .. location)
        rune.echo("Valid locations are:")
        local validLocs = {}
        for _, loc in pairs(wearable) do
            if loc ~= "none" and loc ~= "sleeping" then
                table.insert(validLocs, loc)
            end
        end
        table.sort(validLocs)
        rune.echo(table.concat(validLocs, ", "))
        return
    end
    
    -- Initialize the location table if it doesn't exist
    if not desiredeq[location] then
        desiredeq[location] = {}
    end
    
    -- Check if there's already an item for this level
    if desiredeq[location][level] then
        local existingItemID = desiredeq[location][level]
        local existingName = eqdb[existingItemID] and eqdb[existingItemID].name or "Unknown"
        rune.echo("Warning: Replacing existing item at level " .. level .. ":")
        rune.echo("Old: [" .. existingItemID .. "] " .. existingName)
        rune.echo("New: [" .. itemID .. "] " .. eqdb[itemID].name)
    end
    
    -- Add the item
    desiredeq[location][level] = itemID
    rune.echo("Added " .. eqdb[itemID].name .. " [" .. itemID .. "] to " .. location .. " at level " .. level)
    
    -- Save changes
    saveEQDBToDisk()
end

function purgeUnaccountedInventory()
    -- If an item is not seen during the inventory update, purge it
    rune.dbg("Purging unaccounted inventory items...")
    local count = 0
    for itemID, itemData in pairs(eqdb) do
        if not itemData.seen and not itemData.vaulted then
            eqdb[itemID] = nil
            count = count + 1
        end
    end
    if count > 0 then
        rune.echo("Purged " .. count .. " unaccounted inventory items.")
    else
        rune.echo("No unaccounted inventory items to purge.")
    end
    cleanDesiredEQ()
end

function cleanDesiredEQ()
    local removed = 0
    for slot, levels in pairs(desiredeq) do
        for level, itemID in pairs(levels) do
            if not eqdb[itemID] then
                levels[level] = nil
                removed = removed + 1
            end
        end
        if next(levels) == nil then
            desiredeq[slot] = nil
        end
    end
    if removed > 0 then
        rune.echo("Cleaned " .. removed .. " stale desired equipment entries.")
        saveEQDBToDisk()
    end
end

function triggerInvDataItem(name,line,wildcards)
    -- Triggered when an item is received in inventory data
    local item = tonumber(wildcards[1])
    local itemData = wildcards[2]
    local newitem = false
    
    
    -- Parse the item data
    local parts = {}
    for part in string.gmatch(itemData, "[^,]+") do
        table.insert(parts, part)
    end
    
    if not eqdb[item] then
        eqdb[item] = {}
        newitem = true
    end

    -- Store the item in the eqdb
    eqdb[item].invflags = parts[1]
    eqdb[item].name = string.gsub(parts[2], ",", "")
    eqdb[item].level = tonumber(parts[3])
    eqdb[item].type = eqtype[tonumber(parts[4])]
    eqdb[item].unique = tonumber(parts[5])
    eqdb[item].wornloc = wearable[tonumber(parts[6])]
    eqdb[item].timer = parts[7]
    eqdb[item].container = invcontainer
    eqdb[item].vaulted = false
    eqdb[item].seen = true
    eqdb[item].keyring = false
    eqdb[item].acquiredzone = room.info.zone

    if not eqdb[item].identified then
        eqdb[item].identified = false -- Default to not identified
    end
    if newitem then
        eqdb[item].identified = false

        -- Check if we need to update potion counts
        local potTypes = {"heal", "mana", "move"}
        for _, potType in ipairs(potTypes) do
            local potName = rune.store.get("potion_name_" .. potType)
            if potName and eqdb[item].name == potName then
                rune.dbg("Adding a potion of type: " .. potType)
                local countVar = "potion_count_" .. potType
                local potions = invSearch("-type Potion -name '"..potName.."'")
                rune.store.set(countVar, #potions)
                rune.dbg("Current count of " .. potType .. " potions: " .. #potions)
                --NotifyPotionCounts()
            end
        end    
    end

    -- If this is a tracked key, auto-manage keyring placement.
    if isKeyLikeItem(eqdb[item]) then
        keydbAutoPutForItem(item)
    end

    rune.dbg("Stored inventory item: " .. item .. " in eqdb")
end

function updateContainerInventory()
    rune.dbg("Updating container inventory...")
    local containers = invSearch("-type Container")
    rune.group.enable("invdata")
    for _,container in ipairs(containers) do
        rune.send_raw("invdata " .. container .. " ansi")
    end
end

function startInvData(name,line,wildcards)
    -- If wildcards[1] is a number, update invcontainer
    rune.trigger.enable("trg_invdata_item")
    if wildcards[1] and tonumber(wildcards[1]) then
        invcontainer = tonumber(wildcards[1])
        rune.dbg("Setting invcontainer to: " .. invcontainer)
    else
        invcontainer = nil
    end
end

function startEqData(name,line,wildcards)
    -- If wildcards[1] is a number, update invcontainer
    rune.trigger.enable("trg_invdata_item")
    invcontainer = nil
end

function endInvData(name,line,wildcards)
    -- End the inventory data collection
    rune.dbg("Ending inventory data collection")
    rune.trigger.disable("trg_invdata_item")
    invcontainer = nil
    wornDataFresh = true
    refreshEquippedWeaponDamtype()
    saveEQDBToDisk()
    rune.echo("Inventory data collection ended and saved to disk.")
end

function endEqData(name,line,wildcards)
    -- End the inventory data collection
    rune.dbg("Ending worn equipment inventory data collection")
    rune.trigger.disable("trg_invdata_item")
    invcontainer = nil
    wornDataFresh = true
    refreshEquippedWeaponDamtype()
    saveEQDBToDisk()
    rune.echo("Inventory data collection ended and saved to disk.")
end

function aliasIdentifyItem(line,wildcards)
    local itemId = tostring(wildcards[1])
    -- Triggered when an item is identified
    rune.dbg("Identifying item: " .. itemId)
    rune.group.enable("identify")
    rune.send_raw(line)
end

function triggerEndIdentify(name,line,wildcards)
    -- Triggered when the identify process is ended
    rune.dbg("Ending identify data collection")
    rune.group.disable("identify")
    rune.trigger.disable("trg_end_identify")
    writeTabletoNote(identifyData)
end

function triggerInvMon(name,line,wildcards)
    -- Triggered when an inventory change is detected
    local data = wildcards[1]
    local parts = {}
    for part in string.gmatch(data, "[^,]+") do
        table.insert(parts, part)
    end
    local action = tonumber(parts[1])
    local id = tonumber(parts[2])
    local containerid = tonumber(parts[3])
    local wornloc = tonumber(parts[4])
    rune.dbg("Inventory change detected: action=" .. action .. ", id=" .. id .. ", containerid=" .. (containerid or "nil") .. ", wornloc=" .. (wornloc or "nil"))

    if action == 1 then
        -- Item removed from wear location
        rune.dbg("Item removed from wear location: " .. id .. " (wearloc: " .. wornloc .. ")")
        if eqdb[id] then
            eqdb[id].wornloc = "none"
            refreshEquippedWeaponDamtype()
        else
            rune.dbg("Item " .. id .. " not found in eqdb")
        end
    elseif action == 2 then
        -- Item worn
        rune.dbg("Item worn: " .. id .. " (wearloc: " .. wornloc .. ")")
        if eqdb[id] then
            eqdb[id].wornloc = wearable[wornloc]
            refreshEquippedWeaponDamtype()
        else
            rune.dbg("InvMon: Item " .. id .. " not found in eqdb")
        end
    elseif action == 3 then
        -- Item removed from inventory
        rune.dbg("Item removed from inventory: " .. id)
        if eqdb[id] then
            -- Rot/give/drop may remove a desired key copy; reporting is dynamic based on eqdb,
            -- so removing from eqdb is sufficient.
            if isKeyLikeItem(eqdb[id]) then
                local sig = keySignature(eqdb[id].name, eqdb[id].acquiredzone)
                keydbPendingPuts[sig] = nil
            end
            eqdb[id] = nil
        end
    elseif action == 4 then
        -- Item added to inventory
        rune.dbg("Item added to inventory: " .. id)
        if not eqdb[id] then
            eqdb[id] = {}
        end
        eqdb[id].timestamp = os.time()
    elseif action == 5 then
        -- Item taken out of container
        rune.dbg("Item taken out of container: " .. id .. " (container: " .. containerid .. ")")
        if eqdb[id] then
            eqdb[id].container = nil
        else
            rune.dbg("InvMon: Item " .. id .. " not found in eqdb")
        end
    elseif action == 6 then
        -- Item put into container
        rune.dbg("Item put into container: " .. id .. " (container: " .. containerid .. ")")
        if eqdb[id] then
            eqdb[id].container = containerid
        else
            rune.dbg("InvMon: Item " .. id .. " not found in eqdb")
        end
    elseif action == 7 then
        -- Item consumed
        rune.dbg("Item consumed: " .. id)
        local potTypes = {"heal", "mana", "move"}
        local itemName = eqdb[id] and eqdb[id].name or "Unknown"

        if eqdb[id] then
            -- Keys can rot/expire and are reported here by invmon action 7.
            if isKeyLikeItem(eqdb[id]) then
                local sig = keySignature(eqdb[id].name, eqdb[id].acquiredzone)
                keydbPendingPuts[sig] = nil
            end
            eqdb[id] = nil
        else
            rune.dbg("InvMon: Item " .. id .. " not found in eqdb")
        end

        for _, potType in ipairs(potTypes) do
            local potName = rune.store.get("potion_name_" .. potType)
            if itemName == potName then
                rune.dbg("Potion of type: " .. potType .. " consumed.")
                local countVar = "potion_count_" .. potType
                local currentCount = tonumber(rune.store.get(countVar)) or 0
                rune.store.set(countVar, currentCount - 1)
                rune.echo("Current count of " .. potType .. " potions: " .. (currentCount - 1))
                --NotifyPotionCounts()
            end
        end

    elseif action == 9 then
        -- Item put into vault
        rune.dbg("Item put into vault: " .. id)
        if eqdb[id] then
            eqdb[id].vaulted = true
        else
            rune.dbg("InvMon: Item " .. id .. " not found in eqdb")
        end
    elseif action == 10 then
        -- Item removed from vault
        rune.dbg("Item removed from vault: " .. id)
        if eqdb[id] then
            eqdb[id].vaulted = false
        end
    elseif action == 11 then
        -- Item put into keyring
        rune.dbg("Item put into keyring: " .. id)
        if eqdb[id] then
            eqdb[id].keyring = true
            if isKeyLikeItem(eqdb[id]) then
                local sig = keySignature(eqdb[id].name, eqdb[id].acquiredzone)
                keydbPendingPuts[sig] = nil
            end
        else
            rune.dbg("InvMon: Item " .. id .. " not found in eqdb")
        end
    elseif action == 12 then
        -- Item taken from keyring
        rune.dbg("Item taken from keyring: " .. id)
        if eqdb[id] then
            eqdb[id].keyring = false
        else
            rune.dbg("InvMon: Item " .. id .. " not found in eqdb")
        end
    end
end


function invSearch(args)
    -- Search equipment, return array of matching item IDs
    --rune.dbg("Arguments for invSearch: " .. args)
    if args == "help" then
        invSearchHelp()
        return {}
    end

    local criteria = {}
    
    -- Parse the command line arguments
    local pos = 1
    while pos <= #args do
        -- Find next flag
        local flagStart, flagEnd, flag = args:find("%-(%w+)", pos)
        if not flagStart then break end
        
        -- Move position past the flag
        pos = flagEnd + 1
        
        -- Skip spaces
        pos = args:find("%S", pos) or (pos + 1)
        if pos > #args then break end
        
        local value
        -- Check if the value is quoted
        local quote = args:sub(pos, pos):match("['\"]")
        if quote then
            -- Find the matching closing quote
            local valueStart = pos + 1
            local valueEnd = args:find(quote, valueStart, true)
            if valueEnd then
                value = args:sub(valueStart, valueEnd - 1)
                pos = valueEnd + 1
            else
                -- No closing quote found, use rest of string
                value = args:sub(valueStart)
                pos = #args + 1
            end
        else
            -- Unquoted value - read until next space or end
            local valueStart = pos
            local valueEnd = args:find("%s", valueStart)
            if valueEnd then
                value = args:sub(valueStart, valueEnd - 1)
                pos = valueEnd
            else
                value = args:sub(valueStart)
                pos = #args + 1
            end
        end
        
        criteria[flag:lower()] = value
    end

    --rune.dbg("Searching equipment with criteria:")
    for k,v in pairs(criteria) do
        --rune.dbg(" - " .. k .. " = " .. v)
    end

    -- Helper for level range parsing
    local function levelMatch(itemLevel, critLevel)
        if not itemLevel or not critLevel or critLevel == "" then return true end
        local min, max = critLevel:match("^(%d+)%-(%d+)$")
        if min and max then
            min, max = tonumber(min), tonumber(max)
            return itemLevel >= min and itemLevel <= max
        else
            local num = tonumber(critLevel)
            return num and itemLevel == num
        end
    end

    local function flexibleMatch(item, k, v)
        local field = item[k]
        if field == nil then return false end

        -- Special handling for level range
        if k == "level" then
            return levelMatch(item.level, v)
        end

        -- Special handling for damtype aliases (e.g. acid == acidic bite/slime).
        if k == "damtype" then
            return damtypeMatch(field, v)
        end

        -- Boolean match (accepts true/false, yes/no, 1/0)
        if type(field) == "boolean" then
            local val = tostring(v):lower()
            return (field and (val == "true" or val == "yes" or val == "1")) or
                   (not field and (val == "false" or val == "no" or val == "0"))
        end

        -- Numeric match
        if type(field) == "number" then
            return tonumber(v) == field
        end

        -- Substring, case-insensitive match
        if type(field) == "string" then
            return field:lower():find(v:lower(), 1, true) ~= nil
        end

        -- Table match (e.g. keywords)
        if type(field) == "table" then
            for _, val in ipairs(field) do
                if type(val) == "string" and val:lower():find(v:lower(), 1, true) then
                    return true
                end
            end
            return false
        end

        -- Fallback: strict equality
        return field == v
    end

    -- Search eqdb
    local results = {}
    for id, item in pairs(eqdb) do
        if not item.name or not item.level or not item.type then goto continue end

        local match = true
        for k, v in pairs(criteria) do
            if not flexibleMatch(item, k, v) then
                match = false
                break
            end
        end
        if match then table.insert(results, id) end
        ::continue::
    end

    -- Sort results by level ascending, then by name
    table.sort(results, function(a, b)
        local levelA = eqdb[a].level or 0
        local levelB = eqdb[b].level or 0
        
        -- First compare by level
        if levelA ~= levelB then
            return levelA < levelB
        end
        
        -- If levels are the same, compare by name
        local nameA = eqdb[a].name or ""
        local nameB = eqdb[b].name or ""
        return nameA < nameB
    end)

    return results
end

function aliasInvSearch(name,line,wildcards)
    -- Handle the inv search command
    rune.dbg("Running inventory search with line: " .. (line or ""))
    rune.dbg("Running inventory search with arguments: " .. (wildcards[1] or ""))
    local args = wildcards[1] or ""
    if args == "" then
        rune.echo("Usage: invsearch -name <name> -type <type> -level <level> -wearable <location>")
        return
    end

    -- Default to -name search if no flag provided
    if not (args:find("^%-") or args:find(" %-")) then
        if args:find(" ") and not args:find("^'") then
            args = "'" .. args .. "'"
        end
        args = "-name " .. args
    end

    local results = invSearch(args)
    if #results == 0 then
        rune.echo("No items found matching criteria: " .. args)
        return
    end

    -- Display results
    rune.echo("Found " .. #results .. " items matching criteria: " .. args)
    rune.echo(" ID         | Name                                               | Type         | Level | Location")
    rune.echo("--------------------------------------------------------------------------------------------------------------------")
    for _,itemID in ipairs(results) do
        local loc = ""
        if eqdb[itemID].wornloc and eqdb[itemID].wornloc ~= "none" then
            loc = "Worn: "..eqdb[itemID].wornloc
        elseif eqdb[itemID].container then
            loc = "Container: " .. eqdb[itemID].container
        elseif eqdb[itemID].keyring then
            loc = "Keyring"
        elseif eqdb[itemID].vault then
            loc = "Vault"
        end

        local itemInfo = string.format("%-11d | %-50s | %-12s | %-5d | %s",
            itemID,
            eqdb[itemID].name or "Unknown",
            eqdb[itemID].type or "Unknown",
            eqdb[itemID].level or 0,
            loc
        )
        rune.echo(itemInfo)
    end
end

function aliasInvCount(name,line,wildcards)
    -- Runs an inventory search, but only displays a count of items found
    local args = wildcards[1] or ""
    if args == "" then
        rune.echo("Usage: invcount -name <name> -type <type> -level <level> -wearable <location>")
        return
    end

    -- Default to -name search if no flag provided
    if not (args:find("^%-") or args:find(" %-")) then
        if args:find(" ") and not args:find("^'") then
            args = "'" .. args .. "'"
        end
        args = "-name " .. args
    end

    local results = invSearch(args)
    if #results == 0 then
        rune.echo("No items found matching criteria: " .. args)
        return
    end

    -- Display count
    rune.echo("Found " .. #results .. " items matching criteria: " .. args)

end

function triggerIdentifyData(name,line,wildcards)
    -- Triggered when identify data is received
    -- Remove 'trg_identify_' from the trigger name to know what data is coming
    local trigger = string.sub(name, 14)
    rune.dbg("Identify data received: " .. trigger .. " = " .. line)
    if trigger ~= "continued" then
        lastIdentifyPart = nil
    end

    if trigger == "keywords" then
        -- Type and level of the item
        identifyData = {}
        lastIdentifyPart = nil
        identifyData.keywords = wildcards[1]
        rune.trigger.enable("trg_end_identify")
    elseif trigger == "name" then
        -- Start of a new item
        identifyData.name = string.gsub(wildcards[1], ",", "")
    elseif trigger == "id" then
        -- Item ID - We'll use this to register the item later.
        identifyingItem = tonumber(wildcards[1])
    elseif trigger == "typelevel" then
        -- Type and level of the item
        identifyData.type = wildcards[1]
        identifyData.level = tonumber(wildcards[2])
    elseif trigger == "worthweight" then
        -- Worth and weight of the item
        identifyData.worth = wildcards[1]
        identifyData.weight = tonumber(wildcards[2])
    elseif trigger == "wearable" then
        -- Wearable location of the item
        identifyData.wearable = wildcards[1]
    elseif trigger == "score" then
        -- Score of the item
        identifyData.score = tonumber(wildcards[1])
    elseif trigger == "spells" then
        -- Score of the item
        identifyData.spells = wildcards[1]
        lastIdentifyPart = "spells"
    elseif trigger == "flags" then
        identifyData.flags = wildcards[1]
        lastIdentifyPart = "flags"
    elseif trigger == "continued" and (lastIdentifyPart == "flags" or lastIdentifyPart == "spells") then
        -- Continued flags data
        identifyData[lastIdentifyPart] = identifyData[lastIdentifyPart]..",".. wildcards[1]
    elseif trigger == "owner" then
        -- Owner of the item
        identifyData.owner = wildcards[1]
    elseif trigger == "found_at" then
        -- Where the item was found/acquired
        identifyData.found_at = wildcards[1]
    elseif trigger == "leads_to" then
        -- Where the item was found
        identifyData.destination = wildcards[1]
    elseif trigger == "wtype_avgdam" then
        -- Weapon type and average damage
        identifyData.wtype = wildcards[1]
        identifyData.avgdam = tonumber(wildcards[2])
    elseif trigger == "inflicts_damtype" then
        -- Inflicts damage type
        identifyData.inflicts = wildcards[1]
        identifyData.damtype = wildcards[2]:lower()
    elseif trigger == "specials" then
        -- Special properties of the item
        identifyData.specials = wildcards[1]
    end
end

function triggerEndIdentifySection(name,line,wildcards)
    -- End of an identify section
    if identifyingItem then
        -- Store the identified item in eqdb
        rune.dbg("Ending identify section for item: " .. identifyingItem)
        for key,value in pairs(identifyData) do
            if not eqdb[identifyingItem] then
                eqdb[identifyingItem] = {}
            end
            eqdb[identifyingItem][key] = value
        end
        eqdb[identifyingItem].identified = true

        -- Complete any pending keydb add that was waiting for identify data.
        -- Use force=true because if the add was by explicit ID the player wants it regardless.
        if keydbPendingAdds[identifyingItem] then
            keydbPendingAdds[identifyingItem] = nil
            finalizeKeydbAddFromItem(identifyingItem, true)
        end
    else
        rune.dbg("No item being identified, ignoring end of section.")
    end
end

function abortIdentify(name,line,wildcards)
    -- Abort the identify process
    if identifyingItem and keydbPendingAdds[identifyingItem] then
        keydbPendingAdds[identifyingItem] = nil
        rune.echo("KeyDB: identify aborted for pending key item " .. identifyingItem .. ".")
    end
    rune.group.disable("identify")
    rune.trigger.disable("trg_end_identify")
    identifyingItem = nil
    lastIdentifyPart = nil
    identifyData = {}
end

function aliasItemInfo(name,line,wildcards)
    -- Alias to display item details
    local itemId = tonumber(wildcards[1])
    if not itemId then
        rune.echo("Usage: iteminfo <item_id>")
        return
    end

    displayItemDetails(itemId)
end

function displayItemDetails(itemId)
    -- Display detailed information about an item
    local item = eqdb[itemId]
    if not item then
        rune.echo("Item with ID " .. itemId .. " not found in equipment database.")
        return
    end

    rune.echo("Item Details for ID: " .. itemId)
    for key, value in pairs(item) do
        if type(value) == "table" then
            rune.echo(key .. ": " .. table.concat(value, ", "))
        else
            rune.echo(key .. ": " .. tostring(value))
        end
    end
end

function aliasSaveEqSet(name,line,wildcards)
    -- Alias to save the equipment we're wearing
    -- We'll store each piece in 'desiredeq' in a given slot, with the level of the equipment as a key
    -- Figure out first what we're wearing
    rune.echo("Saving worn equipment to desired equipment table.")
    for slot, loc in pairs(wearable) do
        -- Get the item in this slot
        local wornEquipment = getWornEquipment()
        for loc,itemID in pairs(wornEquipment) do
            local itemData = eqdb[itemID]
            if not desiredeq[loc] then
                desiredeq[loc] = {}
            end
            desiredeq[loc][itemData.level] = itemID
            rune.dbg("Saving item " .. itemID .. " in slot " .. loc .. " with level " .. itemData.level)
        end
    end
end

function getWornEquipment()
    -- Get the currently worn equipment
    local wornEquipment = {}
    for slot, loc in pairs(wearable) do
        for itemId, itemData in pairs(eqdb) do
            if itemData.wornloc == loc then
                wornEquipment[loc] = itemId
                break
            end
        end
    end
    return wornEquipment
end

function aliasUpdateInventoryDetail(name,line,wildcards)
    local items = {}
    -- Time consuming. Perform an identify on all weapons and armor in the inventory
    -- or if 'all' is specified, do all items
    if wildcards[1] == "all" then
        items = invSearch("-identified false -vaulted false")
    else
        items = invSearch("-type Weapon -identified false -vaulted false")
        tableConcat(items, invSearch("-type Armor -identified false -vaulted false"))
        tableConcat(items, invSearch("-type Portal -identified false -vaulted false"))
        tableConcat(items, invSearch("-type Treasure -identified false -vaulted false"))
        for itemID, itemData in pairs(eqdb) do
            if itemData.type == "Weapon" and itemData.identified and (not itemData.damtype or not itemData.wtype) and not itemData.vaulted and not table.contains(items, itemID) then
                table.insert(items, itemID)
            end
        end
    end
    queueIdentify(items)
    rune.echo("Queued " .. #items .. " items for identification. This may take a while. Please wait.")
end

function aliasUpdateInventorySearch(name,line,wildcards)
    -- Time consuming. Perform an identify on all weapons and armor in the inventory
    local items = invSearch(wildcards[1])
    queueIdentify(items)
    rune.echo("Queued " .. #items .. " items for identification. This may take a while. Please wait.")
end

function aliasInvDisplay(name,line,wildcards)
    -- Adds an extra argument up front, the type of item to display so we get a more focused display
    local itemType = wildcards[1]
    local itemFilter = wildcards[2] or ""
    if itemType == "portals" then itemType = "portal" end -- Makes more sense to use portals, but bad for search
    local items = invSearch("-type " .. itemType .. " " .. itemFilter)

    if itemType:lower() == "portal" then
        rune.echo("Portal Search Results:")
        rune.echo(" ID         | Name                                               |  Destination                             |  Level | Keywords")
        rune.echo("---------------------------------------------------------------------------------------------------------------------------------------------------")
        for _,itemID in ipairs(items) do
            local itemdata = eqdb[itemID]

            local itemInfo = string.format("%-11d | %-50s | %-40s | %-6d | %-30s",
                itemID,
                itemdata.name or "Unknown",
                itemdata.destination or "Unknown",
                itemdata.level or 0,
                itemdata.keywords or "None"
                )
            rune.echo(itemInfo)
        end
    elseif itemType:lower() == "weapon" then
        rune.echo("Weapon Search Results:")
        rune.echo(" ID         | Name                                               | Level | Weapon Type | Inflicts           | Damtype")
        rune.echo("---------------------------------------------------------------------------------------------------------------------------------------------------")
        for _,itemID in ipairs(items) do
            local itemdata = eqdb[itemID]

            local itemInfo = string.format("%-11d | %-50s | %-5d | %-11s | %-20s | %-20s",
                itemID,
                itemdata.name or "Unknown",
                itemdata.level or 0,
                itemdata.wtype or "Unknown",
                itemdata.inflicts or "Unknown",
                itemdata.damtype or "Unknown"
                )
            rune.echo(itemInfo)
        end
    end
end

function queueIdentify(items)
    -- For each itemID in the list, queue an identify command
    local delay = 1 -- Delay between identifies to avoid flooding the server
    local ttime = 0
    rune.echo("Identifying critical gear. This will take a while. You can type 'tcancel' to cancel all pending temporary timers and stop the process.")
    for _,itemId in ipairs(items) do
        if eqdb[itemId] and eqdb[itemId].container then
            rune.timer.after(ttime,"take "..itemId.." "..eqdb[itemId].container, {group="temptimers"})
            rune.timer.after(ttime+0.1,function()
               rune.send("id "..tostring(itemId))
            end, {group="temptimers"})
            rune.timer.after(ttime+0.2,"put "..itemId.." "..eqdb[itemId].container, {group="temptimers"})
        elseif eqdb[itemId] and eqdb[itemId].wornloc and eqdb[itemId].wornloc ~= "none" then
            rune.timer.after(ttime,"remove ".. itemId, {group="temptimers"})
            rune.timer.after(ttime+0.1,function()
               rune.send("id "..tostring(itemId))
            end, {group="temptimers"})
            rune.timer.after(ttime+0.2,"wear " .. itemId .. " "..eqdb[itemId].wornloc, {group="temptimers"})
        elseif eqdb[itemId] and eqdb[itemId].keyring then
            rune.timer.after(ttime,"keyring get ".. itemId, {group="temptimers"})
            rune.timer.after(ttime+0.1,function()
               rune.send("id "..tostring(itemId))
            end, {group="temptimers"})
            rune.timer.after(ttime+0.2,"keyring put " .. itemId)
        else
            rune.timer.after(ttime,function()
               rune.send("id "..tostring(itemId))
            end, {group = "temptimers"})
        end
        ttime = ttime + delay
    end
    rune.timer.after(ttime,function(ctx)
       saveEQDBToDisk()
    end)
end

function aliasDumpDesiredEQ(name,line,wildcards)
    -- Alias to display the desired equipment set
    local chosenEquipment = chooseDesiredEquipment(effectiveLevel())
    rune.echo("Desired Equipment Set:")
    rune.echo(" Location   | Item ID    | Item Name")
    rune.echo("--------------------------------------------------------------")
    for slot, itemId in pairs(chosenEquipment) do
        local itemName = eqdb[itemId] and eqdb[itemId].name or "Unknown"
        local itemInfo = string.format("%-11s | %-10d | %s",
            slot,
            itemId,
            itemName
        )
        rune.echo(itemInfo)
    end

end

function aliasEquipForLevel(name,line,wildcards)
    local level = tonumber(wildcards[1]) or effectiveLevel()
    if not level then
        rune.echo("Could not determine level. Usage: eqlevel <level>")
        return
    end

    if not wornDataFresh then
        rune.dbg("Worn equipment data may be stale, refreshing...")
        for _, item in pairs(eqdb) do
            item.wornloc = "none"
        end
        rune.send_raw("eqdata ansi")
        rune.timer.after(2, function(ctx)
            aliasEquipForLevel(name, "equipforlevel " .. (wildcards[1] or ""), wildcards)
        end)
        return
    end

    rune.echo("Equipping optimal gear for level " .. level)
    
    -- Get desired equipment and currently worn equipment
    local desiredEquipment = chooseDesiredEquipment(level)
    local wornEquipment = getWornEquipment()

    -- Track which items we're planning to use (to avoid bagging them)
    local itemsToUse = {}
    for _, itemId in pairs(desiredEquipment) do
        itemsToUse[itemId] = true
    end

    -- Check if we have items equipped in slots that should be empty
    -- (for shield, hold, second weapon)
    if not shieldup then
        -- Dual-wielding mode - ensure shield and held items are not equipped
        rune.dbg("Dual-wielding mode: removing shield and held items if equipped")
        for _, slot in ipairs({"shield", "hold"}) do
            if wornEquipment[slot] then
                local itemId = wornEquipment[slot]
                if eqdb[itemId] and eqdb[itemId].wornloc == slot then
                    rune.dbg("Removing " .. slot .. " item: " .. itemId)
                    rune.send_raw("remove " .. itemId)
                    local bagKey = selectBagForItem(itemId)
                    if bagKey then
                        rune.send_raw("put " .. itemId .. " " .. bagKey)
                    end
                end
            end
        end
    else
        rune.dbg("Shield up mode: removing second weapon if equipped")
        -- Shield up mode - ensure second weapon is not equipped
        if wornEquipment["second"] then
            local itemId = wornEquipment["second"]
            if eqdb[itemId] and eqdb[itemId].wornloc == "second" then
                rune.dbg("Removing second weapon: " .. itemId)
                local bagKey = selectBagForItem(itemId)
                if bagKey then
                    rune.send_raw("remove " .. itemId)
                    rune.send_raw("put " .. itemId .. " " .. bagKey)
                end
            end
        end
    end

    -- Process each slot individually to avoid conflicts
    for slot, location in pairs(wearable) do
        if location ~= "none" then
            local currentItemID = wornEquipment[location]
            local desiredItemID = desiredEquipment[location]
            
            -- Skip if no desired item for this slot or we're already wearing the right item
            if not desiredItemID or currentItemID == desiredItemID then
                goto continue
            end
            
            -- Handle removing current item if any
            if currentItemID and eqdb[currentItemID] and eqdb[currentItemID].wornloc == location then
                rune.send_raw("remove " .. currentItemID)
                
                -- Only bag the item if it's not going to be used elsewhere
                if not itemsToUse[currentItemID] then
                    local bagKey = selectBagForItem(currentItemID)
                    if bagKey then
                        rune.send_raw("put " .. currentItemID .. " " .. bagKey)
                    end
                end
            end
            
            -- Handle wearing desired item
            local itemData = eqdb[desiredItemID]
            if not itemData then
                rune.echo("Warning: Item " .. desiredItemID .. " not found in equipment database")
                goto continue
            end
            
            -- First, get the item if it's in a container or keyring
            if itemData.container then
                rune.send_raw("get " .. desiredItemID .. " " .. itemData.container)
            elseif itemData.keyring then
                rune.send_raw("keyring get " .. desiredItemID)
            elseif itemData.vaulted then
                rune.echo("Warning: Item " .. desiredItemID .. " (" .. (itemData.name or "Unknown") .. ") is in your vault and cannot be equipped automatically")
                goto continue
            end
            
            -- Then wear the item
            rune.send_raw("wear " .. desiredItemID .. " " .. location)
            
            ::continue::
        end
    end
    
    rune.echo("Equipment changes completed for level " .. level)
end


function chooseDesiredEquipment(level)
    -- Choose the desired equipment based on the level
    local chosenEquipment = {}

    local function gatherItemIDsByExactName(itemName)
        local matches = {}
        for itemID, itemData in pairs(eqdb) do
            if itemData and itemData.name == itemName then
                table.insert(matches, itemID)
            end
        end
        table.sort(matches, function(a, b)
            local na = tonumber(a)
            local nb = tonumber(b)
            if na and nb then return na < nb end
            return tostring(a) < tostring(b)
        end)
        return matches
    end

    local function chooseBestHelmOverride(maxLevel)
        local bestID = nil
        local bestLevel = -1
        for _, itemID in ipairs(gatherItemIDsByExactName("Aardwolf Helm of True Sight")) do
            local item = eqdb[itemID]
            local itemLevel = tonumber(item and item.level) or 0
            if item and not item.vaulted and itemLevel <= maxLevel and itemLevel > bestLevel and canWearHeroOnlyItem(item) then
                bestLevel = itemLevel
                bestID = itemID
            end
        end
        return bestID
    end

    local function chooseWingsOverride()
        for _, itemID in ipairs(gatherItemIDsByExactName("Wings of Aardwolf")) do
            local item = eqdb[itemID]
            if item and not item.vaulted and canWearHeroOnlyItem(item) then
                return itemID
            end
        end
        return nil
    end
    
    -- First, select best equipment for each slot based on level
    for slot, items in pairs(desiredeq) do
        if items[level] then
            local candidateID = items[level]
            local candidateItem = eqdb[candidateID]
            if canWearHeroOnlyItem(candidateItem) then
                chosenEquipment[slot] = candidateID
            end
        end
        if not chosenEquipment[slot] then
            -- If no exact match, find the highest level item below the desired level
            local maxLevel = -1
            for itemLevel, itemId in pairs(items) do
                local item = eqdb[itemId]
                if itemLevel <= level and itemLevel > maxLevel and canWearHeroOnlyItem(item) then
                    maxLevel = itemLevel
                    chosenEquipment[slot] = itemId
                end
            end
        end
    end
    
    -- Then, adjust based on shieldup setting
    if shieldup == false then
        -- Dual-wielding mode - remove shield and held items
        chosenEquipment["shield"] = nil
        chosenEquipment["hold"] = nil
        -- Keep second weapon for dual-wielding
    else
        -- Shield up mode - remove second weapon
        chosenEquipment["second"] = nil
        -- Keep shield and held items
    end

    -- Slot overrides (applied after shieldup/dual adjustments).
    if wingsOverride then
        local wingsItemID = chooseWingsOverride()
        if wingsItemID then
            chosenEquipment["back"] = wingsItemID
        else
            rune.echo("Wings override is ON, but no non-vaulted 'Wings of Aardwolf' was found.")
        end
    end

    if helmOverride then
        local helmItemID = chooseBestHelmOverride(level)
        if helmItemID then
            chosenEquipment["head"] = helmItemID
        else
            rune.echo("Helm override is ON, but no non-vaulted 'Aardwolf Helm of True Sight' at or below level " .. tostring(level) .. " was found.")
        end
    end
    
    return chosenEquipment
end

function aliasEquipDamtype(name, line, wildcards)
    local damtype = wildcards[1]
    if not damtype or damtype == "" then
        rune.echo("Usage: dt <damtype>")
        return
    end

    local weapons = invSearch("-type Weapon -damtype '" .. damtype .. "' -vaulted false")
    if #weapons == 0 then
        rune.echo("No weapons found with damage type: " .. damtype)
        return
    end

    local effectiveLvl = effectiveLevel()
    local bestWeaponID = nil
    local bestLevel = -1
    for _, itemID in ipairs(weapons) do
        local item = eqdb[itemID]
        if item and item.level and item.level <= effectiveLvl and item.level > bestLevel and not hasChangingFlag(item) then
            bestLevel = item.level
            bestWeaponID = itemID
        end
    end

    if not bestWeaponID then
        rune.echo("No suitable weapon found for damage type: " .. damtype .. " (effective level: " .. effectiveLvl .. ")")
        return
    end

    local bestItem = eqdb[bestWeaponID]
    local wornEquipment = getWornEquipment()
    local currentWielded = wornEquipment["wielded"]
    local currentSecond = wornEquipment["second"]

    if currentWielded == bestWeaponID then
        rune.echo("Already wielding best " .. damtype .. " weapon: " .. (bestItem.name or "Unknown"))
        return
    end

    if currentSecond == bestWeaponID then
        rune.send_raw("remove " .. bestWeaponID)
    end

    if currentWielded and currentWielded ~= bestWeaponID then
        rune.send_raw("remove " .. currentWielded)
        local bagKey = selectBagForItem(currentWielded)
        if bagKey then
            rune.send_raw("put " .. currentWielded .. " " .. bagKey)
        end
    end

    if bestItem.container then
        rune.send_raw("get " .. bestWeaponID .. " " .. bestItem.container)
    elseif bestItem.keyring then
        rune.send_raw("keyring get " .. bestWeaponID)
    end

    rune.send_raw("wield " .. bestWeaponID)
    refreshEquippedWeaponDamtype()
    rune.echo("Wielding: " .. (bestItem.name or "Unknown") .. " [" .. (bestItem.damtype or "?") .. "]")
end

function aliasQuaffPotion(name,line,wildcards)
    local potionType = wildcards[1]
    local potionKey = rune.store.get("potion_keyword_"..potionType)
    local potionName = rune.store.get("potion_name_"..potionType)
    if not potionKey or not potionName then
        rune.echo("Nothing registered for potion type: " .. potionType..". Please set it using "..potionType.."pot <name>  (full name of the potion)")
        return
    else
        -- Check count of potions
        local potions = invSearch("-type Potion -name '"..potionName.."'")

        if #potions == 0 then
            rune.echo("WARNING: You are out of "..potionType.." potions!")
        else
            if #potions < 5 then
                rune.echo("WARNING: You have only " .. #potions .. " "..potionType.." potions left!")
            end
            rune.send_raw("quaff " .. potionKey)
        end
    end
end

function aliasSetPotion(name,line,wildcards)
    -- Get a sample item by searching inventory
    local potionType = wildcards[1]
    local matchingItems = invSearch("-name '"..wildcards[2].."' -type potion")

    if #matchingItems == 0 then
        rune.echo("No items inventory matching name: " .. wildcards[2])
        return
    end
    -- We'll have to do a two-step process, if we don't know the keywords for the item.
    settingPotionType = potionType
    settingPotionID = matchingItems[1]
    if eqdb[settingPotionID] and eqdb[settingPotionID].keywords then
        -- We have the keywords, so we can set it directly
        rune.store.set("potion_keyword_"..settingPotionType, eqdb[settingPotionID].keywords)
        rune.store.set("potion_name_"..settingPotionType, eqdb[settingPotionID].name)
        rune.echo("Set potion type '" .. potionType .. "' to keywords: " .. eqdb[settingPotionID].keywords)
    else
        -- We need to identify the item first
        rune.echo("Identifying potion: " .. eqdb[settingPotionID].name .. "...")
        rune.timer.after(1,function(ctx)
           setPotionKeywords()
        end)
        rune.send_raw("id " .. settingPotionID)
    end
end

function setPotionKeywords()
    -- This function is called after identifying the potion
    if not settingPotionID or not settingPotionType then
        rune.echo("No potion set for keywords.")
        return
    end
    if not eqdb[settingPotionID].keywords then
        rune.echo("Potion ID keywords for " .. settingPotionID .. " not found in eqdb.")
        return
    end
    
    if not settingPotionID or not settingPotionType or not eqdb[settingPotionID].keywords then
        rune.echo("Failed to grab potion keywords.")
        return
    end

    rune.store.set("potion_keyword_"..settingPotionType, eqdb[settingPotionID].keywords)
    rune.store.set("potion_name_"..settingPotionType, eqdb[settingPotionID].name)
    rune.echo("Set potion type '" .. settingPotionType .. "' to keywords: " .. eqdb[settingPotionID].keywords)
    
    settingPotionType = nil
    settingPotionID = nil
end

function NotifyPotionCounts()
    local counts = {}
    -- Notify the status window about current potion counts
    
    local potTypes = {"heal", "mana", "move"}
    for _, potionType in ipairs(potTypes) do
        local potionKey = rune.store.get("potion_keyword_"..potionType)
        local potionName = rune.store.get("potion_name_"..potionType)
        local potions = invSearch("-type Potion -name '"..potionName.."'")
        table.insert(counts,#potions)
    end
    local msg = table.concat(counts, "|")
    --rune.dbg("Notifying potion counts to status window: "..msg)
    --BroadcastPlugin(100,msg)
end

function aliasEQBag(name,line,wildcards)
    -- Alias to manage bags for storing equipment
    -- Need to split wildcards[1] by spaces to get the action and arguments
    local args = wildcards[1] and wildcards[1]:split(" ") or {}
    local action = args[1] and args[1]:lower() or nil
    table.remove(args, 1) -- Remove the action from the args
    if not wildcards[1] then
        rune.echo("Usage: eqbag <add|delete|list> [bag_key] [minlevel] [maxlevel]")
        return
    end
    
    if action == "add" then
        -- add a bag to the list
        local bagKey = args[1] or ""
        local minlevel = tonumber(args[2]) or 0
        local maxlevel = tonumber(args[3]) or 0
        if bagKey == "" or minlevel <= 0 or maxlevel == 0 or maxlevel > 291 then
            rune.echo("Usage: eqbag add <bag_key> [minlevel] [maxlevel]")
            return
        end
        if not bags[bagKey] then
            -- Check if bag level range overlaps with existing bags
            for existingKey, existingData in pairs(bags) do
                if (minlevel <= existingData.maxlevel and maxlevel >= existingData.minlevel) or
                   (existingData.minlevel <= maxlevel and existingData.maxlevel >= minlevel) then
                    rune.echo("Bag '" .. bagKey .. "' overlaps with existing bag '" .. existingKey .. "'. Please choose a different level range.")
                    return
                end
            end
            -- Add the bag to the bags table
            bags[bagKey] = {minlevel = minlevel, maxlevel = maxlevel}
            rune.echo("Added bag '" .. bagKey .. "' with level range " .. minlevel .. "-" .. maxlevel)
            return
        else
            rune.echo("Bag '" .. bagKey .. "' already exists.")
            return
        end
    elseif action == "delete" then
        -- delete a bag from the list
        local bagKey = args[1] or ""
        if bagKey == "" then
            rune.echo("Usage: eqbag delete <bag_key>")
            return
        end
        if bags[bagKey] then
            bags[bagKey] = nil
            rune.echo("Deleted bag '" .. bagKey .. "'")
        else
            rune.echo("Bag '" .. bagKey .. "' not found.")
        end
    elseif action == "list" or action == nil then
        -- list all bags
        -- Order bags by minlevel ascending
        local sortedBags = {}
        for bagKey, data in pairs(bags) do
            table.insert(sortedBags, {key = bagKey, minlevel = data.minlevel, maxlevel = data.maxlevel})
        end
        table.sort(sortedBags, function(a, b) return a.minlevel < b.minlevel end)

        if next(bags) == nil then
            rune.echo("No bags defined.")
            return
        end
        rune.echo("Defined equipment bags:")
        rune.echo(" Bag Key       | Level Range")
        rune.echo("--------------------------------")
        for bagKey, data in pairs(sortedBags) do
            rune.echo(string.format("%-15s | %d-%d", bagKey, data.minlevel, data.maxlevel))
        end
    else
        rune.echo("Unknown action: " .. action)
        rune.echo("Usage: eqbag <add|delete|list>")
    end
end

function selectBagForItem(itemId)
    -- Select the appropriate bag for the item based on its level
    if not eqdb[itemId] then
        rune.dbg("Item " .. itemId .. " is not known, please update your inventory.")
        return nil
    end
    local itemLevel = eqdb[itemId].level or 0
    rune.dbg("Selecting bag for item " .. itemId .. " with level " .. itemLevel)
    for bagKey, data in pairs(bags) do
        if itemLevel >= data.minlevel and itemLevel <= data.maxlevel then
            rune.dbg("Selected bag '" .. bagKey .. "' for item " .. itemId)
            return bagKey
        end
    end
end

function aliasUnbag(name,line,wildcards)
    -- Alias to unbag an item from a bag
    local itemId = tonumber(wildcards[1])
    if not itemId then
        rune.echo("Usage: unbag <item_id>")
        return
    end

    if not eqdb[itemId] or not eqdb[itemId].container then
        -- Won't do anything.
        return
    end

    local container = eqdb[itemId].container
    eqdb[itemId].lastContainer = eqdb[itemId].container -- Store the last container for reference
    rune.send_raw("get " .. itemId .. " " .. container)
    --rune.echo("Unbagged item " .. itemId .. " from container " .. container)
end

function aliasRebag(name, line, wildcards)
    -- Alias to rebag an item into a bag
    local itemId = tonumber(wildcards[1])
    if not itemId then
        rune.echo("Usage: rebag <item_id>")
        return
    end

    if not eqdb[itemId] or not eqdb[itemId].lastContainer then
        --Ignore it, leave in inventory
        return
    end

    local lastContainer = eqdb[itemId].lastContainer
    eqdb[itemId].lastContainer = nil -- Clear the last container after rebagging
    rune.send_raw("put " .. itemId .. " " .. lastContainer)
    --rune.echo("Rebagged item " .. itemId .. " into container " .. lastContainer)
end

function aliasTransport(name,line,wildcards)
    -- Alias to use a handheld portal 
    local itemId = tonumber(wildcards[1]) or nil
    if itemId == nil then
        -- Try to find the item by name
        rune.dbg("Searching for portal by keywords: " .. wildcards[1])
        local itemName = wildcards[1]
        local searchResults = invSearch("-keywords '" .. itemName .. "' -type Portal")
        if #searchResults == 1 then
            itemId = searchResults[1]
            rune.dbg("Found portal item with ID: " .. itemId)
        elseif #searchResults > 1 then
            rune.echo("Multiple items found with name '" .. itemName .. "'. Please specify the item ID.")
            return
        end
    end
    
    if not itemId then
        rune.echo("Usage: transport <item_id>")
        return
    end

    if not eqdb[itemId] then
        rune.echo("Item with ID " .. itemId .. " not found in equipment database.")
        return
    end

    if eqdb[itemId].type ~= "Portal" then
        rune.echo("Item with ID " .. itemId .. " is not a portal.")
        return
    end

    -- Get itemID equipped in portal wear location
    local equippedPortal = invSearch("-wornloc portal")
    -- Determine if portal is in a container, worn, or in inventory
    local currentLoc = "inventory"
    if eqdb[itemId].container then
        -- Item is in a container
        currentLoc = "container"
        rune.dbg("Using portal " .. itemId .. " from container " .. eqdb[itemId].container)
    end
    if equippedPortal == itemId then
        -- Item is worn in portal location, just use it.
        rune.send_raw("enter")
        rune.dbg("Using portal " .. itemId .. " from worn location")
        return
    end
    if equippedPortal[1] then
        rune.send_raw("remove " .. equippedPortal[1])
    end
    if currentLoc == "container" then
        -- Take the item out of the container first
        eqdb[itemId].lastContainer = eqdb[itemId].container -- Store the last container for reference
        rune.send_raw("get " .. itemId .. " " .. eqdb[itemId].container)
    end
    rune.send_raw("wear " .. itemId .. " portal") -- Wear the portal item in the portal location
    rune.send_raw("enter")
    rune.send_raw("remove " .. itemId) -- Remove the portal item after entering
    if currentLoc == "container" then
        -- Put the item back into the container after using it
        rune.send_raw("put " .. itemId .. " " .. eqdb[itemId].lastContainer)
        eqdb[itemId].lastContainer = nil -- Clear the last container after using
    end
    if equippedPortal[1] then
        -- If we had a portal equipped, put it back on
        rune.send_raw("wear " .. equippedPortal[1] .. " portal")
        --rune.dbg("Re-equipped portal " .. equippedPortal[1] .. " after using " .. itemId)
    end
end

function configShieldup(name, line, wildcards)
    if name == "alias_shield_up" then
        shieldup = true
        rune.store.set("shieldup", "true")
        rune.echo("Shield up mode enabled. You will automatically wear your shield when equipping weapons.")
    elseif name == "alias_dual_wield" then
        shieldup = false
        rune.store.set("shieldup", "false")
        rune.echo("Dual wield mode enabled. You will not automatically wear your shield when equipping weapons.")
    end
    rune.send("equipforlevel") -- Re-equip to apply the new shield setting
end

function configAardwolfOverrides(name, line, wildcards)
    local setting = (wildcards[1] or ""):lower()
    if setting ~= "on" and setting ~= "off" then
        rune.echo("Usage: " .. ((name == "alias_wings_override") and "wings" or "helm") .. " <on|off>")
        return
    end

    local enabled = (setting == "on")
    if name == "alias_wings_override" then
        wingsOverride = enabled
        rune.store.set("wings_override", enabled and "true" or "false")
        rune.echo("Wings override " .. (enabled and "enabled" or "disabled") .. ".")
    elseif name == "alias_helm_override" then
        helmOverride = enabled
        rune.store.set("helm_override", enabled and "true" or "false")
        rune.echo("Helm override " .. (enabled and "enabled" or "disabled") .. ".")
    end

    rune.send("equipforlevel")
end

require("aardrune/aliases/equipment_aliases")
require("aardrune/triggers/equipment_triggers")


-- Initialization and data saving/loading
if not initialized then initializeEQPlugin() end

rune.gmcp.on("char.status", function(data)
    local currentLevel = tonumber(data.level) or 0
    if initialized and lastKnownLevel ~= nil and currentLevel ~= lastKnownLevel then
        rune.send("equipforlevel")
    end
    lastKnownLevel = currentLevel
end)
