local initialized = false
local lastRenderKey = nil
local refreshPending = false
local refreshRate = 0.5

function initializeStatus()
    if initialized then
        return
    end
    rune.dbg("Robbo_StatusWin: Initializing status window.")
    rune.pane.create("status")
    updateStatusWindow()
    initialized = true
end

local function scheduleUpdate()
    if refreshPending then return end
    refreshPending = true
    rune.timer.after(refreshRate, function()
        refreshPending = false
        updateStatusWindow()
    end)
end

rune.gmcp.on("char.base", function(data)
    scheduleUpdate()
end)

rune.gmcp.on("char.vitals", function(data)
    scheduleUpdate()
end)

rune.gmcp.on("char.stats", function(data)
    scheduleUpdate()
end)

rune.gmcp.on("char.maxstats", function(data)
    scheduleUpdate()
end)

rune.gmcp.on("char.status", function(data)
    scheduleUpdate()
end)

rune.gmcp.on("char.worth", function(data)
    rune.dbg("char.worth GMCP: " .. serialize.save_simple(data))
    scheduleUpdate()
end)

rune.gmcp.on("room.info", function(data)
    if charState() == "RUNNING" then return end
    scheduleUpdate()
end)

function updateStatusWindow()
    local align = tonumber(char.status and char.status.align) or 0
    if align <= -800 then
        align = acs("@R") .. align
    elseif align >= 800 then
        align = acs("@W") .. align
    else
        align = acs("@D") .. align
    end

    local curQmob = questmob or ""
    local curQroom = questroom or ""
    local curQarea = questzone or ""
    local curQtime = qtime or "--"

    local curCpindex = cpIndex or 0
    local curCpmob = ""
    local curCplocation = ""
    if cpmobs and cpmobs[curCpindex] then
        curCpmob = cpmobs[curCpindex].name or ""
        curCplocation = cpmobs[curCpindex].location or ""
    end

    local curHeal = rune.store.get("potion_count_heal") or "--"
    local curMana = rune.store.get("potion_count_mana") or "--"
    local curMove = rune.store.get("potion_count_move") or "--"

    local curExits = ""
    if room.info and room.info.num then
        local roomUID = tostring(room.info.num)
        curExits = getRoomExits(roomUID)
    end

    local lines = {
        acs("@G -Campaign/GQ- @W"),
        acs(string.format("@G%5s @C%s", "Idx:", curCpindex)),
        acs(string.format("@G%5s @C%s", "Name:", curCpmob)),
        acs(string.format("@G%5s @C%s", "Loc:", curCplocation)),
        "",
        acs("@G -Quest- @W"),
        acs(string.format("@G%5s @C%s", "Time:", curQtime)),
        acs(string.format("@G%5s @C%s", "Area:", curQarea)),
        acs(string.format("@G%5s @C%s", "Room:", curQroom)),
        acs(string.format("@G%5s @C%s", "Mob:", curQmob)),
        "",
        acs("@G -Potions-@W"),
        acs(string.format("@G%5s @C%s  @G%5s @C%s  @G%5s @C%s", "Heal:", curHeal, "Mana:", curMana, "Move:", curMove)),
        "",
        acs("@G -Char Info- @W"),
        acs(string.format("@G%6s @C%-6s@G%-7s @C%-5s@W", "Lvl:", (char.status and char.status.level) or "0", " Tells:", (char.base and char.base.tells) or "0")),
        acs(string.format("@G%6s @C%-6s @G%6s @C%-7s@W", "Tnl:", tostring((char.status and char.status.tnl) or "0"), "QP:", formatWithCommas(tonumber((char.worth and char.worth.qp)) or 0))),
        acs(string.format("@G%6s @C%-6s   @G%6s @C%-10s@W", "Align:", align, "Gold:", formatWithCommas(tonumber((char.worth and char.worth.gold)) or 0))),
        acs(string.format("@G%6s @C%-6s @G%6s @C%-7s@W", "Train:", tostring(tonumber((char.worth and char.worth.trains)) or 0), "Prac:", tostring(tonumber((char.worth and char.worth.pracs)) or 0))),
        acs("@GState: @C" .. charState() .. "@W"),
        "",
        acs("@G -Combat- @W"),
        acs(string.format("@G%6s @C%-25s", "Enemy:", (char.status and char.status.enemy) or "")),
        acs(string.format("@G%6s @C%s", "Queue:", table.concat(killqueue or {}, ", "))),
        "",
        acs(string.format("@G%-14s %5s @C%d@W", " -Room-", "Num:", (room.info and room.info.num) or 0)),
        acs(string.format("@G%6s @C%-25s", "Name:", (room.info and room.info.name) or "")),
        acs(string.format("@G%6s @C%-15s", "Zone:", (room.info and room.info.zone) or "")),
        acs(string.format("@G%6s @C%-20s", "Exits:", curExits))
    }

    local renderKey = table.concat(lines, "\n")
    if renderKey == lastRenderKey then
        return
    end
    lastRenderKey = renderKey

    rune.pane.replace("status", renderKey)
end

initializeStatus()

rune.pane.create("status")
rune.alias.exact("tstatus", function()
   rune.pane.toggle("status")
end)
