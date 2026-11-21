local desiredBypasses = {}
local currentBypasses = {}
local allowedSlots = 0
local lastKnownLevel = nil
local bypassStateKnown = false

local function countKeys(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local function loadDesiredBypasses()
    local saved = rune.store.get("bypass_desired")
    if saved then
        local f, err = load("return " .. saved)
        if f then
            local ok, parsed = pcall(f)
            if ok and type(parsed) == "table" then
                desiredBypasses = parsed
            end
        end
    end
end

local function saveDesiredBypasses()
    rune.store.set("bypass_desired", serialize.save_simple(desiredBypasses))
end

local function getRealLevel()
    return tonumber(char.status.level) or 0
end

local function isValidLevel(level)
    return type(level) == "number" and level >= 1 and level <= 201
end

local function isAreaAppropriate(areaInfo, playerLevel)
    if not isValidLevel(playerLevel) then
        return false
    end
    if not areaInfo or not areaInfo.levelMin or not areaInfo.levelMax then
        return true
    end
    return playerLevel >= areaInfo.levelMin and playerLevel <= areaInfo.levelMax
end

function onCharStatus(data)
    local currentLevel = tonumber(data.level)
    if not isValidLevel(currentLevel) then
        return
    end
    if lastKnownLevel == nil then
        lastKnownLevel = currentLevel
        reconcileBypasses()
    elseif currentLevel ~= lastKnownLevel then
        lastKnownLevel = currentLevel
        reconcileBypasses()
    end
end

function requestBypassState()
    currentBypasses = {}
    rune.send("bypass")
end

function triggerBypassCaptureStart(name, line, wildcards)
    currentBypasses = {}
end

function triggerBypassCaptureLine(name, line, wildcards)
    local areaName, levelMin, levelMax, keyword, percent, slotType = line:match("^%s+%-%s+(.+)%s+%[(%d+)%s*%-%s*(%d+)%]%s+%((%w+)%)%s+%((%d+)%% %- (%w+)%)$")
    if areaName and keyword then
        currentBypasses[keyword] = {
            name = areaName,
            levelMin = tonumber(levelMin),
            levelMax = tonumber(levelMax),
            percent = tonumber(percent),
            slotType = slotType
        }
    end
end

function triggerBypassCaptureEnd(name, line, wildcards)
    local slots = line:match("^You are allowed to bypass (%d+) areas%.?$")
    if slots then
        allowedSlots = tonumber(slots)
        bypassStateKnown = true
        reconcileBypasses()
    end
end

function displayBypassStatus()
    local currentCount = countKeys(currentBypasses)
    rune.echo("Current bypasses (" .. currentCount .. "/" .. allowedSlots .. "):")
    for keyword, info in pairs(currentBypasses) do
        rune.echo(string.format("  %-15s %-40s [%d-%d] %d%% %s",
            keyword, info.name, info.levelMin, info.levelMax, info.percent, info.slotType))
    end
    rune.echo("")
    local desiredCount = countKeys(desiredBypasses)
    rune.echo("Desired bypasses (" .. desiredCount .. "):")
    local sorted = {}
    for keyword, data in pairs(desiredBypasses) do
        table.insert(sorted, {keyword = keyword, priority = data.priority, name = data.name})
    end
    table.sort(sorted, function(a, b) return a.priority < b.priority end)
    for _, item in ipairs(sorted) do
        local status = currentBypasses[item.keyword] and "ACTIVE" or "pending"
        rune.echo(string.format("  %2d %-15s %-40s [%s]", item.priority, item.keyword, item.name, status))
    end
end

function aliasBpmList(name, line, wildcards)
    displayBypassStatus()
end

function aliasBpmHelp(name, line, wildcards)
    rune.echo("Bypass Manager Commands:")
    rune.echo("  bpm              - List current and desired bypasses")
    rune.echo("  bpm update       - Reconcile desired list with MUD state")
    rune.echo("  bpm clear        - Clear all desired bypasses")
    rune.echo("  bpm <keyword>    - Toggle area in desired bypass list")
    rune.echo("  bpmp <kw> <pri>  - Set priority for ordering (lower = higher priority)")
    rune.echo("  bpm help         - Show this help")
    rune.echo("")
    rune.echo("The bypass manager maintains a list of areas you want to bypass.")
    rune.echo("Use 'bpm update' to sync your desired list with the MUD, respecting")
    rune.echo("slot limits and removing bypasses for areas out of your level range.")
end

function aliasBpmToggle(name, line, wildcards)
    local keyword = wildcards[1]:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if keyword == "" then
        rune.echo("Usage: bpm <keyword>")
        return
    end

    if desiredBypasses[keyword] then
        desiredBypasses[keyword] = nil
        rune.echo("Removed " .. keyword .. " from desired bypasses")
    else
        local areaInfo = getAreaInfo(keyword)
        if not areaInfo then
            rune.echo("Area '" .. keyword .. "' not found in mapper database")
            return
        end
        local playerLevel = getRealLevel()
        if not isAreaAppropriate(areaInfo, playerLevel) then
            rune.echo("Warning: Area level range [" .. areaInfo.levelMin .. "-" .. areaInfo.levelMax .. "] may not be appropriate for level " .. playerLevel)
        end
        local maxPriority = 0
        for _, data in pairs(desiredBypasses) do
            if data.priority > maxPriority then maxPriority = data.priority end
        end
        desiredBypasses[keyword] = {
            priority = maxPriority + 1,
            name = areaInfo.name
        }
        rune.echo("Added " .. keyword .. " to desired bypasses (priority " .. (maxPriority + 1) .. ")")
    end
    saveDesiredBypasses()
    reconcileBypasses()
end

function aliasBpmSetPriority(name, line, wildcards)
    local keyword = wildcards[1]:lower():gsub("^%s+", ""):gsub("%s+$", "")
    local priority = tonumber(wildcards[2])
    if not keyword or not priority then
        rune.echo("Usage: bpmp <keyword> <priority>")
        return
    end
    if not desiredBypasses[keyword] then
        rune.echo("Area '" .. keyword .. "' is not in desired bypasses")
        return
    end
    desiredBypasses[keyword].priority = priority
    saveDesiredBypasses()
    rune.echo("Set priority for " .. keyword .. " to " .. priority)
end

function aliasBpmClear(name, line, wildcards)
    desiredBypasses = {}
    saveDesiredBypasses()
    rune.echo("Cleared all desired bypasses")
    reconcileBypasses()
end

function aliasBpmUpdate(name, line, wildcards)
    reconcileBypasses()
end

function reconcileBypasses()
    if not bypassStateKnown then
        requestBypassState()
        return
    end

    local playerLevel = getRealLevel()
    if not isValidLevel(playerLevel) then
        rune.dbg("Bypass reconciliation skipped: invalid character level (" .. tostring(playerLevel) .. ")")
        return
    end
    local sorted = {}
    for keyword, data in pairs(desiredBypasses) do
        table.insert(sorted, {keyword = keyword, priority = data.priority})
    end
    table.sort(sorted, function(a, b) return a.priority < b.priority end)

    local toAdd = {}
    local toRemove = {}
    local slotsUsed = countKeys(currentBypasses)

    for keyword, info in pairs(currentBypasses) do
        local inDesired = false
        for _, item in ipairs(sorted) do
            if item.keyword == keyword then
                inDesired = true
                break
            end
        end
        if not inDesired then
            table.insert(toRemove, keyword)
        elseif not isAreaAppropriate(info, playerLevel) then
            table.insert(toRemove, keyword)
        end
    end

    slotsUsed = slotsUsed - #toRemove

    for _, item in ipairs(sorted) do
        if slotsUsed >= allowedSlots then
            break
        end
        if not currentBypasses[item.keyword] then
            local areaInfo = getAreaInfo(item.keyword)
            rune.dbg("Checking desired area: " .. item.keyword .. " - areaInfo: " .. tostring(areaInfo and (areaInfo.levelMin .. "-" .. areaInfo.levelMax) or "nil"))
            if isAreaAppropriate(areaInfo, playerLevel) then
                rune.dbg("  -> Adding " .. item.keyword)
                table.insert(toAdd, item.keyword)
                slotsUsed = slotsUsed + 1
            else
                rune.dbg("  -> Not appropriate for level " .. playerLevel)
            end
        end
    end

    for _, keyword in ipairs(toRemove) do
        rune.echo("Removing bypass: " .. keyword)
        rune.send("bypass " .. keyword)
        currentBypasses[keyword] = nil
    end

    for i, keyword in ipairs(toAdd) do
        rune.echo("Adding bypass: " .. keyword)
        local areaInfo = getAreaInfo(keyword)
        if i == 1 and #toRemove > 0 then
            rune.send("bypass " .. keyword .. " first")
        else
            rune.send("bypass " .. keyword)
        end
        if areaInfo then
            currentBypasses[keyword] = {
                name = areaInfo.name,
                levelMin = areaInfo.levelMin,
                levelMax = areaInfo.levelMax,
                percent = 0,
                slotType = "Pending"
            }
        end
    end

    if #toAdd == 0 and #toRemove == 0 then
        rune.echo("Bypass list is already up to date")
    end
end

require("aardrune/aliases/bypass_aliases")
require("aardrune/triggers/bypass_triggers")

loadDesiredBypasses()

rune.gmcp.on("char.status", function(data)
    onCharStatus(data)
end)
