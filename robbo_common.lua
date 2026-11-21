require("aardrune/serialize")
local layout = require("aardrune/layout")
layout.init()


local _activityState = { quest = false, gq = false, cp = false }

do
    local saved = rune.store.get("activity_state")
    if saved then
        rune.dbg("Loading activity state from store: " .. saved)
        local f, err = load("return " .. saved)
        if f then
            local ok, parsed = pcall(f)
            if ok and type(parsed) == "table" then
                _activityState = parsed
                rune.dbg("Activity state loaded: quest=" .. tostring(_activityState.quest) .. " gq=" .. tostring(_activityState.gq) .. " cp=" .. tostring(_activityState.cp))
            else
                rune.dbg("Failed to parse activity state: " .. tostring(parsed))
            end
        else
            rune.dbg("Failed to create loader for activity state: " .. tostring(err))
        end
    else
        rune.dbg("No saved activity state found in store")
    end
end

function setActivity(activity, active)
    if _activityState[activity] == nil then return end
    _activityState[activity] = active and true or false
    rune.store.set("activity_state", serialize.save_simple(_activityState))
    rune.dbg("Activity updated: " .. activity .. " = " .. tostring(active) .. " | current activity: " .. tostring(getActivity()))
end

function getActivity()
    if _activityState.quest then return "quest" end
    if _activityState.gq then return "gq" end
    if _activityState.cp then return "cp" end
    return nil
end

function getCurrentGQMob()
    if type(gqmobs) ~= "table" or #gqmobs == 0 then return nil end
    local idx = gqIndex or 0
    if idx == 0 or idx > #gqmobs then idx = 1 end
    return gqmobs[idx]
end

function getCurrentCPMob()
    if type(cpmobs) ~= "table" or #cpmobs == 0 then return nil end
    local idx = cpIndex or 0
    if idx == 0 or idx > #cpmobs then idx = 1 end
    return cpmobs[idx]
end

-- Plugin name to ID mapping for alias reloading
pluginIDMap = {
    ["mapper"] = mapperPluginID,
    ["mobdb"] = mobdbPluginID,
    ["combat"] = combatPluginID,
    ["movement"] = movementPluginID,
    ["quest"] = questPluginID,
    ["eq"] = eqPluginID,
    ["statuswin"] = statuswindowPluginID,
    ["spellup"] = spellupPluginID
}

--local debug_mode = GetVariable("debug_mode")
--if debug_mode == nil then
   -- Default debug mode to "off" if not set
   debug_mode = "on"
   --SetVariable("debug_mode", debug_mode)
--end

function showTriggers()
   -- Rune stores triggers in a table, but doesn't provide a built-in way to list them. This function lists all triggers and their properties.
    local t = rune.trigger.list() 
    for i,trigger in ipairs(t) do
        local name = trigger.name or "Unnamed"
        local action = trigger.action or "No action"
        local priority = trigger.priority or "No priority"
        local group = trigger.group or "No group"
        local gag = trigger.gag and "Yes" or "No"
        rune.echo(string.format("Trigger %d: Name='%s', Pattern='%s', Priority=%s, Group='%s', Gag=%s", i, name, pattern, priority, group, gag))
   end
end

function showAliases()
    local t = rune.alias.list()
    for i,alias in ipairs(t) do
        local name = alias.name or "Unnamed"
        local pattern = alias.pattern or "No pattern"
        local script = alias.script or "No script"
        local group = alias.group or "No group"
        rune.echo(string.format("Alias %d: Name='%s', Pattern='%s', Script='%s', Group='%s'", i, name, pattern, script, group))
    end
end


-- Lookup tables
local charStates = {
  [1]  = "LOGIN",
  [2]  = "MOTD",
  [3]  = "READY",
  [4]  = "AFK",
  [5]  = "NOTE",
  [6]  = "EDIT",
  [7]  = "PAGEDPROMPT",
  [8]  = "COMBAT",
  [9]  = "SLEEPING",
  [11] = "RESTING",
  [12] = "RUNNING"
}

-- Shared globals (used across multiple modules)
killqueue = {}
qtime = 30
onquest = false
room = { info = {} }

-- Common functions
local ESC = string.char(27)

local ANSI_NAME_TO_CODE = {
  -- misc
  reset = 0,
  bold = 1,
  blink = 3,      -- often rendered as italic
  underline = 4,
  inverse = 7,

  nobold = 22,
  noblink = 23,
  nounderline = 24,
  noinverse = 27,

  -- foreground
  black = 30,
  red = 31,
  green = 32,
  yellow = 33,
  blue = 34,
  magenta = 35,
  cyan = 36,
  white = 37,

  -- background (common aliases)
  bg_black = 40, black_back = 40,
  bg_red = 41, red_back = 41,
  bg_green = 42, green_back = 42,
  bg_yellow = 43, yellow_back = 43,
  bg_blue = 44, blue_back = 44,
  bg_magenta = 45, magenta_back = 45,
  bg_cyan = 46, cyan_back = 46,
  bg_white = 47, white_back = 47,
}

-- Add/replace near ANSI_NAME_TO_CODE:

local ANSI_FG_NAME_TO_CODE = {
  -- normal fg
  black = 30, red = 31, green = 32, yellow = 33,
  blue = 34, magenta = 35, cyan = 36, white = 37,

  -- bright fg aliases
  gray = 90, grey = 90,
  brightblack = 90,
  brightred = 91,
  brightgreen = 92,
  brightyellow = 93,
  brightblue = 94,
  brightmagenta = 95,
  brightcyan = 96,
  brightwhite = 97,

  -- common named colours used in help text
  chartreuse = 92,   -- closest bright green
  deeppink = 95,     -- closest bright magenta
}

local ANSI_BG_NAME_TO_CODE = {
  -- normal bg
  black = 40, red = 41, green = 42, yellow = 43,
  blue = 44, magenta = 45, cyan = 46, white = 47,

  -- bright bg aliases
  gray = 100, grey = 100,
  brightblack = 100,
  brightred = 101,
  brightgreen = 102,
  brightyellow = 103,
  brightblue = 104,
  brightmagenta = 105,
  brightcyan = 106,
  brightwhite = 107,

  chartreuse = 102,  -- closest bright green bg
  deeppink = 105,    -- closest bright magenta bg
}

-- Keep existing ANSI_NAME_TO_CODE for style/reset tokens if you like.
-- Update ANSI(...) so it still works for style tokens and numeric codes.
function ANSI(...)
  local out = {}
  local n = select("#", ...)

  if n == 0 then
    return ESC .. "[0m"
  end

  for i = 1, n do
    local v = select(i, ...)
    local t = type(v)

    if t == "number" then
      out[#out + 1] = tostring(math.floor(v))
    elseif t == "string" then
      local s = v:lower():gsub("%s+", ""):gsub("-", "_")
      local num = tonumber(s)
      if num then
        out[#out + 1] = tostring(num)
      else
        local mapped = ANSI_NAME_TO_CODE[s]
        if mapped then
          out[#out + 1] = tostring(mapped)
        end
      end
    end
  end

  if #out == 0 then
    out[1] = "0"
  end

  return ESC .. "[" .. table.concat(out, ";") .. "m"
end

-- Pad a string to a fixed visible width, ignoring embedded ANSI escape codes.
-- justify: "left" (default), "right", or "center"
function strpad(s, width, justify)
  s = tostring(s)
  justify = justify or "left"
  local visible = #s:gsub("\27%[[%d;]*m", ""):gsub("@x%d%d%d", ""):gsub("@%w", "")
  local space = width - visible
  if space <= 0 then return s end
  if justify == "right" then
    return string.rep(" ", space) .. s
  elseif justify == "center" then
    local lpad = math.floor(space / 2)
    return string.rep(" ", lpad) .. s .. string.rep(" ", space - lpad)
  else
    return s .. string.rep(" ", space)
  end
end

-- New helpers + ColourNote equivalent:

local COLOUR_NAME_TO_ACS = {
  black = "@x000", red = "@r", green = "@g", yellow = "@y",
  blue = "@b", magenta = "@m", cyan = "@c", white = "@w",
  gray = "@D", grey = "@D", silver = "@D",
  brightblack = "@D", brightred = "@R", brightgreen = "@G",
  brightyellow = "@Y", brightblue = "@B", brightmagenta = "@M",
  brightcyan = "@C", brightwhite = "@W",
  gold = "@Y", tomato = "@R", lightgreen = "@G",
  deepskyblue = "@C", lightgray = "@D", lightgrey = "@D",
}

function ColourNote(fg, bg, text)
  if not text or text == "" then
    if not fg or fg == "" then rune.echo("") return end
  end
  local code = COLOUR_NAME_TO_ACS[(fg or ""):lower()] or "@w"
  rune.echo(acs(code .. (text or "")))
end

function ColourTell(fg, bg, text)
  if not text or text == "" then
    if not fg or fg == "" then return end
  end
  local code = COLOUR_NAME_TO_ACS[(fg or ""):lower()] or "@w"
  rune.echo(acs(code .. (text or "")))
end


local AARDWOLF_COLOR_MAP = {
    b = 34, B = 94,
    c = 36, C = 96,
    r = 31, R = 91,
    m = 35, M = 95,
    g = 32, G = 92,
    y = 33, Y = 93,
    w = 37, W = 97,
    D = 90,
}

function acs(s)
    s = s:gsub("@([bcrmygwBCRMYGWD])", function(ch)
        local code = AARDWOLF_COLOR_MAP[ch]
        if code then
            return ESC .. "[" .. code .. "m"
        end
        return "@" .. ch
    end)
    s = s:gsub("@x(%d%d%d)", function(num)
        local n = tonumber(num)
        if n and n >= 0 and n <= 256 then
            if n == 256 then n = math.random(0, 255) end
            return ESC .. "[38;5;" .. n .. "m"
        end
        return "@x" .. num
    end)
    return s
end

function toggleConfig(v,p)
   -- Toggle a configuration setting
   -- v is the current value, p is the parameter passed
   if p == 'on' or p == 'off' then
      v = p
   elseif b == 'on' then
      v = 'off'
   elseif b == 'off' then
      v = 'on'
   end
   return v
end

function tNilTozero(t,k)
   -- If a table value is undefined/nil, return zero instead
   local v = t[k]
   if v == nil then v = 0 end
   return tonumber(v)
end

function tableConcat(t1,t2)
   -- Concatenate two tables into one
   for _,v in ipairs(t2) do
      table.insert(t1, v)
   end
end

function math.round(x)
   -- Round a number to the nearest integer
   if x == nil then return end
   return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end

function formatWithCommas(n)
   -- Format a number with comma thousands separators
   local s = tostring(math.floor(n or 0))
   local k
   while true do
      s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
      if k == 0 then break end
   end
   return s
end

function countMatches(base, pattern)
   -- Count the number of matches of a pattern in a string
   base = string.lower(base)
   pattern = string.lower(pattern)
   return select(2, string.gsub(base, pattern, ""))
end

function DebugNote(s)
   -- Pops debug data through, but only if debug_mode is set to "on" 
   rune.dbg("RobboPlugs DEBUG: "..s)
end

function jsonDecode(jsonString)
   -- Decode a JSON string into a Lua table
   local json = require("json")
   local success, result = pcall(json.decode, jsonString)
   if not success then
      rune.echo("Error decoding JSON: " .. result)
      return nil
   end
   return result
end

function stringToTable(str)
  -- Ensure the string returns a value
  local f, err = load("return " .. str)
  if not f then
    error("Failed to parse string: " .. err)
  end
  local success, result = pcall(f)
  if not success then
    error("Error executing string: " .. result)
  end
  return result
end

function getTableKeys(t)
  -- Returns list of table keys, sorted
  local keyset = {}
  for k,v in pairs(t) do
    keyset[#keyset + 1] = k
  end
  table.sort(keyset)
  return keyset
end

function arrayRemoveEntry(t,value)
    -- Remove a value from an array table
    if type(t) ~= "table" then
        return {}
    end
    for i, v in ipairs(t) do
        if v == value then
            table.remove(t, i)
            return t
        end
    end
    return t
end


function table.contains(table, element)
   -- Check if a table contains a specific value
   if type(table) ~= "table" then return false end
   for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

function table.count(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

function string.split (inputstr, sep)
   -- Split a string into a table using a delimiter
   if sep == nil then
      sep = "%s"
   end
   local t={}
   for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
   end
   return t
end

function string.concat(...)
   -- Concatenate a number of strings together with a delimiter as the first argument
   local delim = table.remove(arg)
   local t = {}
   for i,v in ipairs(arg) do
      table.insert(t,v)
   end
   return table.concat(t,delim)
end

function string.capitalize(str)
   -- Capitalize the first letter of a string
   if str == nil or str == "" then return "" end
   return str:sub(1, 1):upper() .. str:sub(2):lower()
end

function writeTabletoFile(t,f,ikey,p)
   -- Dump contents of array to open file 'f'
   -- Uses pairs
   -- Make sure you open and close the file!
   -- Can pass ikey (area-nn) for parsable output
   if t == nil then return end
   local keys = getTableKeys(t)
   local maxlen = 0
   --Prepass for formatting
   for i,k in ipairs(keys) do
      if string.len(k) > maxlen then maxlen = string.len(k) end
   end
   for i,k in ipairs(keys) do
      if p == true then
         -- Parsable = .tsv file
         f:write(ikey.."\t"..k.."\t"..t[k].."\n")
      else
         f:write(string.format("%"..maxlen.."s",k)..": "..t[k].."\n")
      end
   end
   if p ~= true then f:write("\n") end
end

function writeTabletoNote(t)
   -- Dump contents of array to output(Note)
   -- Uses pairs
   -- Make sure you open and close the file!
   if t == nil then return end
   rune.echo(serialize.save_simple(t))
end

function writeArraytoFile(t,f)
   -- Dump contents of array to open file 'f'
   -- Uses ipairs, so iterative
   -- Make sure you open and close the file!
   if t == nil then return end
   for i,v in ipairs(t) do
      f:write(v.."\n")
   end
   f:write("\n")
end

function writeArraytoNote(t)
   -- Dump contents of array to Output (Note)
   -- Uses ipairs, so iterative
   if t == nil then return end
   for i,v in ipairs(t) do
      rune.echo(v)
   end
   rune.echo()
end

-- MUSHClient Utility
function clearTempTimers()
   -- Clear all temporary timers, use in the case of emergency
   rune.echo("Clearing all temporary timers!")
   DeleteTemporaryTimers ()
end

-- lookup functions

function getGMCP(g)
   -- Returns GMCP value for given key
   local res
   local val
   rune.echo("Debug: Something is calling getGMCP, check for it.")
   --res, val = CallPlugin("3e7dedbe37e44942dd46d264","gmcpval",g)
   return val
end

function charState()
   -- Returns the current character state
   -- Uses GMCP
   if char.status == nil then return "UNKNOWN" end
   local state = char.status.state
   if state == nil then return "UNKNOWN" end
   return charStates[state] or "UNKNOWN"
end

function effectiveLevel()
   -- Returns effective level of the player
   -- Uses GMCP
   local level = tonumber(char.status.level)
   local tier = tonumber(char.base.tier)
   return tier * 10 + level
end

function proxyExec(name,line,wildcards)
   -- Proxy function to execute a command
   -- Used for aliases and commands
   local cmd = table.concat(wildcards, " ")
   if cmd == "" then
      rune.echo("No command specified.")
      return
   end
   rune.send_raw(cmd)
end

function isAFK()
   -- Check if the character is AFK
   -- Uses GMCP
   local state = charState()
   return state == "AFK"
end

function robbotSend(channel, message)
   -- AFK-aware sending 
   local isAFK = isAFK()
    if isAFK then rune.send_raw("afk") end
    rune.send_raw(channel.. " " .. message)
    if isAFK then rune.send_raw("afk") end
end

function stripMobTags(line)
  local tags = {}
  local remaining = line

  while true do
    -- Match a tag at the start, with optional leading space before it
    -- Capture the tag (with parentheses), and the rest of the line
    local tag, rest = remaining:match("^%s*(%([^%)]+%))%s*(.*)")
    if not tag then break end
    table.insert(tags, tag)
    remaining = rest
  end

  -- Trim any leading whitespace left after all tags removed
  remaining = remaining:match("^%s*(.-)%s*$")

  return remaining, tags
end

function isPluginLoaded(pluginID)
   -- Check if a plugin with the given ID is loaded
   local plugins = GetPluginList()
   for _, plugin in ipairs(plugins) do
      if plugin == pluginID then
         return true
      end
   end
   return false
end


function flexibleSearch(t,args)
    -- Search table, return array of matching item IDs
    rune.dbg("Arguments for searching: " .. args)

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

    --rune.dbg("Searching table with criteria:")
    for k,v in pairs(criteria) do
        --rune.dbg(" - " .. k .. " = " .. v)
    end

    local function levelMatch(item, critLevel)
        if not critLevel or critLevel == "" then return true end
        local itemMin, itemMax
        if item.minlevel and item.maxlevel then
            itemMin = tonumber(item.minlevel)
            itemMax = tonumber(item.maxlevel)
        elseif item.level then
            itemMin = tonumber(item.level)
            itemMax = itemMin
        else
            return false
        end
        if not itemMin or not itemMax then return false end
        local critMin, critMax = critLevel:match("^(%d+)%-(%d+)$")
        if critMin and critMax then
            critMin, critMax = tonumber(critMin), tonumber(critMax)
            return itemMin <= critMax and itemMax >= critMin
        else
            local num = tonumber(critLevel)
            return num and num >= itemMin and num <= itemMax
        end
    end

    local function flexibleMatch(item, k, v)
        local field = item[k]
        if field == nil then return false end

        if k == "level" then
            return levelMatch(item, v)
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

    -- Search table
    local results = {}
    for id, item in pairs(t) do
        --if not item.name or not item.level or then goto continue end

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
        local levelA = t[a].level or 0
        local levelB = t[b].level or 0
        
        -- First compare by level
        if levelA ~= levelB then
            return levelA < levelB
        end
        
        -- If levels are the same, compare by name
        local nameA = t[a].name or ""
        local nameB = t[b].name or ""
        return nameA < nameB
    end)

    return results
end

-- Helper: print a coloured help line
-- cmd: the command/syntax (highlighted), desc: description (normal)
function helpCmd(cmd, desc)
    local msg = acs("@G  " .. tostring(cmd or ""))
    if desc and desc ~= "" then
        msg = msg .. acs("@w  - " .. tostring(desc))
    end
    rune.echo(msg)
end

function helpHeader(text)
    rune.echo(acs("@c" .. tostring(text or "")))
end

function helpSection(text)
    rune.echo(acs("@M" .. tostring(text or "") .. ":"))
end

function helpRule()
    rune.echo(acs("@D" .. string.rep("-", 60)))
end

function drawbar(label, current, maximum, okcolor, warningcolor, criticalcolor, width, reverse)
    local percent

    if reverse then
        percent = 1 - (current / maximum)
    else
        percent = current / maximum
    end

    percent = math.max(0, math.min(1, percent))

    local color

    if percent >= 0.60 then
        color = okcolor
    elseif percent >= 0.20 then
        color = warningcolor
    else
        color = criticalcolor
    end

    local filled = math.floor(percent * width + 0.5)

    local labeltext = label ~= "" and label .. ":" or ""
    local valuetext = string.format("%d/%d", current, maximum)

    local value_space = width - #labeltext

    local value_pos = math.floor((value_space - #valuetext) / 2) + 1

    local chars = {}
    for i = 1, width do
        chars[i] = " "
    end

    if labeltext ~= "" then
        for i = 1, #labeltext do
            if i <= width then
                chars[i] = labeltext:sub(i, i)
            end
        end
    end

    for i = 1, #valuetext do
        local pos = #labeltext + value_pos + i - 1
        if pos <= width then
            chars[pos] = valuetext:sub(i, i)
        end
    end

    local result = ANSI(0) .. "["

    if filled > 0 then
        result = result .. ANSI(color) .. ANSI(30)

        for i = 1, filled do
            result = result .. chars[i]
        end
    end

    if filled < width then
        result = result .. ANSI(0)

        for i = filled + 1, width do
            result = result .. chars[i]
        end
    end

    result = result .. ANSI(0) .. "]"

    return result
end

-- ============================================================
-- Planes (Upper/Lower Planes) shared utilities
-- ============================================================

-- Area keys that indicate a mob is in the planes zones
local _planesAreaPatterns = { "uplanes", "lplanes", "upper planes", "lower planes" }

-- Pool number -> display name
planesPools = {
    [1]  = "Gladsheim",
    [2]  = "Pandemonium",
    [3]  = "Hades",
    [4]  = "Gehenna",
    [5]  = "Acheron",
    [6]  = "Twin Paradises",
    [7]  = "Arcadia",
    [8]  = "Seven Heavens",
    [9]  = "Swordbreaker's Hoard",
    [10] = "Elysium",
    [11] = "Beastlands",
    [12] = "Realm of the Zodiac",
    [13] = "Thandeld's Conflict",
    [14] = "Nine Hells",
}

-- Partial strings to match pool from room name (lowercased)
local _planesPoolPatterns = {
    [1]  = "gladsheim",
    [2]  = "pandemonium",
    [3]  = "hades",
    [4]  = "gehenna",
    [5]  = "acheron",
    [6]  = "twin paradises",
    [7]  = "arcadia",
    [8]  = "seven heavens",
    [9]  = "swordbreaker",
    [10] = "elysium",
    [11] = "beastlands",
    [12] = "zodiac",
    [13] = "thandeld",
    [14] = "nine hells",
}

--- Return true if areaKey refers to the upper or lower planes zones.
function isPlanesArea(areaKey)
    if not areaKey then return false end
    local a = areaKey:lower()
    for _, pa in ipairs(_planesAreaPatterns) do
        if a == pa or a:find(pa, 1, true) then return true end
    end
    return false
end

--- Given a room name string, return the pool number (1-14) or nil.
function getPoolFromRoomName(roomName)
    if not roomName then return nil end
    local rn = roomName:lower()
    for num, pattern in pairs(_planesPoolPatterns) do
        if rn:find(pattern, 1, true) then return num end
    end
    return nil
end


-- Moved from Equipment
-- Canonical damage type aliases for invSearch -damtype matching.
damtypeAliases = {
    acid = {"acid", "acidic bite", "digestion", "slime"},
    air = {"air"},
    bash = {"bash", "beating", "blast", "charge", "crush", "hit", "pound", "punch", "slap", "smash", "suction", "thwack"},
    cold = {"cold", "chill", "freezing bite"},
    earth = {"earth"},
    electric = {"electric", "shock", "shocking bite"},
    energy = {"energy", "friction", "wrath", "explosive energy"},
    fire = {"fire", "flame", "flaming bite"},
    holy = {"holy", "divine power"},
    light = {"light"},
    magic = {"magic"},
    mental = {"mental", "mental energy", "mind force", "anguish"},
    negative = {"negative", "decaying touch", "life drain"},
    pierce = {"pierce", "bite", "chomp", "peck", "scratch", "stab", "sting", "thrust"},
    slash = {"slash", "chop", "claw", "cleave", "grep", "slice", "whip"},
    shadow = {"shadow"},
    sonic = {"sonic", "wail"},
    water = {"water", "water blast"}
}

-- Physical damage types, all others are magic-based
physicaldamtypes = {"bash","pierce","slash"}

damtypeCanonicalByAlias = {}
for canonical, aliases in pairs(damtypeAliases) do
    for _, alias in ipairs(aliases) do
        damtypeCanonicalByAlias[alias] = canonical
    end
end

function normalizeDamtype(value)
    if value == nil then return nil end
    local normalized = tostring(value):lower():gsub("^%s+", ""):gsub("%s+$", "")
    return damtypeCanonicalByAlias[normalized] or normalized
end

function damtypeMatch(itemDamtype, queryDamtype)
    local queryCanonical = normalizeDamtype(queryDamtype)
    if not queryCanonical then return false end

    -- Damtype is expected to be a string, but support comma-delimited values defensively.
    local itemText = tostring(itemDamtype)
    for token in itemText:gmatch("[^,]+") do
        if normalizeDamtype(token) == queryCanonical then
            return true
        end
    end

    return false
end

combatSpells = {
    ["Air dart"] = { level = 1, spell = 465, damtype = "Air" },
    ["Bash"] = { level = 1, damtype = "Bash" },
    ["Burning hands"] = { level = 1, spell = 7, damtype = "Fire" },
    ["Cause light"] = { level = 1, spell = 12, damtype = "Magic" },
    ["Chill touch"] = { level = 1, spell = 16, damtype = "Cold" },
    ["Circle"] = { level = 1, damtype = "Pierce" },
    ["Earth maw"] = { level = 1, spell = 380, damtype = "Earth" },
    ["Holy rain"] = { level = 1, spell = 364, damtype = "Water" },
    ["Kick"] = { level = 1, damtype = "Bash" },
    ["Kobold stench"] = { level = 1, damtype = "Disease" },
    ["Magic missile"] = { level = 1, spell = 62, damtype = "Magic" },
    ["Rune of ix"] = { level = 1, spell = 43, damtype = "Energy" },
    ["Soulburn"] = { level = 1, spell = 363, damtype = "Fire" },
    ["Burnt marbu"] = { level = 5, damtype = "Poison" },
    ["Banshee wail"] = { level = 6, spell = 170, damtype = "Sonic" },
    ["Cause serious"] = { level = 7, spell = 13, damtype = "Magic" },
    ["Moonbeam"] = { level = 8, spell = 144, damtype = "Light" },
    ["Backstab"] = { level = 13, damtype = "Weapon" },
    ["Minor swarm"] = { level = 14, spell = 191, damtype = "Disease" },
    ["Shocking grasp"] = { level = 14, spell = 73, damtype = "Electric" },
    ["Dirt kicking"] = { level = 15, damtype = "Bash" },
    ["Colour spray"] = { level = 19, spell = 17, damtype = "Light" },
    ["Earthquake"] = { level = 19, spell = 39, damtype = "Earth" },
    ["Black root"] = { level = 20, damtype = "Bash" },
    ["Wind blast"] = { level = 20, spell = 381, damtype = "Air" },
    ["Wither"] = { level = 21, spell = 187, damtype = "Negative" },
    ["White flame"] = { level = 23, spell = 366, damtype = "Fire" },
    ["Prismatic spray"] = { level = 24, spell = 177, damtype = "Light" },
    ["Trip"] = { level = 24, damtype = "Bash" },
    ["Spirit bolt"] = { level = 27, spell = 365, damtype = "Special" },
    ["Fireball"] = { level = 28, spell = 45, damtype = "Fire" },
    ["Cause critical"] = { level = 30, spell = 11, damtype = "Magic" },
    ["Vampiric touch"] = { level = 32, spell = 179, damtype = "Negative" },
    ["Angel breath"] = { level = 34, spell = 190, damtype = "Magic" },
    ["Fire storm"] = { level = 34, spell = 148, damtype = "Fire" },
    ["Dispel evil"] = { level = 36, spell = 37, damtype = "Holy" },
    ["Dispel good"] = { level = 36, spell = 184, damtype = "Shadow" },
    ["Teleport behind"] = { level = 36, spell = 79, damtype = "Magic" },
    ["Major swarm"] = { level = 40, spell = 192, damtype = "Disease" },
    ["Heavenly smiting"] = { level = 41, spell = 574, damtype = "Holy" },
    ["Hydra blood"] = { level = 41, damtype = "Disease" },
    ["Ground strike"] = { level = 42, spell = 382, damtype = "Earth" },
    ["Lightning bolt"] = { level = 42, spell = 60, damtype = "Electric" },
    ["Flamestrike"] = { level = 44, spell = 47, damtype = "Fire" },
    ["Flame arrow"] = { level = 48, spell = 173, damtype = "Fire" },
    ["Harm"] = { level = 49, spell = 52, damtype = "Magic" },
    ["Ice storm"] = { level = 49, spell = 150, damtype = "Cold" },
    ["Whirlwind"] = { level = 51, spell = 383, damtype = "Air" },
    ["Acid blast"] = { level = 52, spell = 3, damtype = "Acid" },
    ["Cobra bane"] = { level = 53, damtype = "Poison" },
    ["Torment"] = { level = 55, spell = 367, damtype = "Negative" },
    ["Cone of cold"] = { level = 59, spell = 172, damtype = "Cold" },
    ["Enhanced backstab"] = { level = 60, damtype = "Weapon" },
    ["Solar flare"] = { level = 60, spell = 384, damtype = "Energy" },
    ["Fire blast"] = { level = 65, spell = 379, damtype = "Fire" },
    ["Raven scourge"] = { level = 65, damtype = "Disease" },
    ["Flaming sphere"] = { level = 66, spell = 346, damtype = "Fire" },
    ["Rainbow"] = { level = 70, spell = 145, damtype = "Light" },
    ["Blight"] = { level = 71, spell = 368, damtype = "Disease" },
    ["Talon"] = { level = 75, spell = 347, damtype = "Pierce" },
    ["Necrotic touch"] = { level = 77, damtype = "Poison" },
    ["Angelfire"] = { level = 78, spell = 373, damtype = "Magic" },
    ["Demonfire"] = { level = 78, spell = 30, damtype = "Negative" },
    ["Green death"] = { level = 78, damtype = "Disease" },
    ["Ice cloud"] = { level = 82, spell = 85, damtype = "Cold" },
    ["Light arrow"] = { level = 83, spell = 331, damtype = "Light" },
    ["Force bolt"] = { level = 84, spell = 348, damtype = "Magic" },
    ["Hydroblast"] = { level = 86, spell = 385, damtype = "Water" },
    ["Call lightning"] = { level = 89, spell = 8, damtype = "Electric" },
    ["Kobold spray"] = { level = 89, damtype = "Disease" },
    ["Extinguish"] = { level = 91, spell = 374, damtype = "Water" },
    ["Shard of ice"] = { level = 93, spell = 352, damtype = "Cold" },
    ["Cyclone"] = { level = 95, spell = 386, damtype = "Air" },
    ["Fire breath"] = { level = 97, spell = 84, damtype = "Fire" },
    ["Engulf"] = { level = 102, spell = 375, damtype = "Fire" },
    ["Shock aura"] = { level = 103, spell = 87, damtype = "Electric" },
    ["Fire rain"] = { level = 107, spell = 453, damtype = "Fire" },
    ["Earth shroud"] = { level = 108, spell = 387, damtype = "Earth" },
    ["Scorch"] = { level = 109, spell = 350, damtype = "Fire" },
    ["Exorcise"] = { level = 114, spell = 369, damtype = "Holy" },
    ["Acid wave"] = { level = 116, spell = 83, damtype = "Acid" },
    ["Marbu jet"] = { level = 121, damtype = "Poison" },
    ["Tornado"] = { level = 121, spell = 388, damtype = "Air" },
    ["Caustic rain"] = { level = 126, spell = 376, damtype = "Water" },
    ["Balefire"] = { level = 127, spell = 231, damtype = "Fire" },
    ["Purge"] = { level = 127, spell = 370, damtype = "Holy" },
    ["Nova"] = { level = 135, spell = 349, damtype = "Light" },
    ["Sweep"] = { level = 135, damtype = "Pierce" },
    ["Ice bolt"] = { level = 137, spell = 389, damtype = "Cold" },
    ["Vengeance"] = { level = 137, spell = 371, damtype = "Light" },
    ["Balor spittle"] = { level = 140, damtype = "Poison" },
    ["Lightning strike"] = { level = 146, spell = 232, damtype = "Electric" },
    ["Spiritual disruption"] = { level = 146, spell = 377, damtype = "Energy" },
    ["Holy word"] = { level = 150, spell = 165, damtype = "Holy" },
    ["Forestfire"] = { level = 152, spell = 390, damtype = "Fire" },
    ["Miasma"] = { level = 157, spell = 351, damtype = "Acid" },
    ["Starburst"] = { level = 160, spell = 372, damtype = "Light" },
    ["Tempest"] = { level = 163, spell = 391, damtype = "Air" },
    ["Toxic cloud"] = { level = 165, spell = 86, damtype = "Poison" },
    ["Spiral"] = { level = 171, damtype = "Weapon, Special" },
    ["Finger of death"] = { level = 172, spell = 95, damtype = "Mental" },
    ["Air skewer"] = { level = 173, spell = 592, damtype = "Air" },
    ["Acid stream"] = { level = 174, spell = 320, damtype = "Acid" },
    ["Earthen hammer"] = { level = 175, spell = 591, damtype = "Earth" },
    ["Eruption"] = { level = 177, spell = 392, damtype = "Earth" },
    ["Gaias fury"] = { level = 177, spell = 626, damtype = "Earth" },
    ["Ice daggers"] = { level = 177, spell = 593, damtype = "Water" },
    ["Banishment"] = { level = 178, spell = 169 },
    ["Voice of god"] = { level = 179, spell = 378, damtype = "Sonic" },
    ["Void sermon"] = { level = 179, spell = 625, damtype = "Negative" },
    ["Immolate"] = { level = 181, spell = 361, damtype = "Fire" },
    ["Spear of odin"] = { level = 181, spell = 541, damtype = "Electric" },
}

rune.alias.exact("getactivity", function()
    rune.echo("Activity state:")
    rune.echo("  quest: " .. tostring(_activityState.quest))
    rune.echo("  gq:    " .. tostring(_activityState.gq))
    rune.echo("  cp:    " .. tostring(_activityState.cp))
    rune.echo("Current activity: " .. tostring(getActivity()))
    local gqmob = getCurrentGQMob()
    local cpmob = getCurrentCPMob()
    if gqmob then
        rune.echo("Current GQ mob: " .. tostring(gqmob.name) .. " (" .. tostring(gqmob.location) .. ")")
    end
    if cpmob then
        rune.echo("Current CP mob: " .. tostring(cpmob.name) .. " (" .. tostring(cpmob.location) .. ")")
    end
end)

-- Load layout aliases after layout module is initialized
require("aardrune/aliases/layout_aliases")
