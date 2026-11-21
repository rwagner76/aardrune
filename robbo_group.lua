local initialized = false
local lastRenderKey = nil

-- Helper to get current compact mode
local function isGroupCompact()
    local val = rune.store.get("groupcompact")
    return val == nil and false or (val == true or val == "true")
end

-- Notify layout system of current compact state on load
local function initGroupCompact()
    if layout and layout.setGroupCompact then
        layout.setGroupCompact(isGroupCompact())
    else
        rune.timer.after(0.5, initGroupCompact)
    end
end

initGroupCompact()


function OnPluginInstall()
    DoAfterSpecial(180, "initializeGroupPlugin()",sendto.script)
end

function initializeGroupPlugin()
    if IsConnected() and not initialized then
        rune.dbg("Robbo_Group_Monitor: Initializing group monitor plugin.")
        rune.send("protocols gmcp sendgroup")
        rune.gmcp.send("group on")
        
        -- Set the initial state of the status window
        initialized = true
    end
end



function groupUpdate(gt)
    -- Update the group window with the latest group information
    if gt.groupname == nil or gt.leader == nil then
        -- Not in a group
        gt.groupname = ""
        gt.leader = ""
        gt.members = {}
    end

    local lines = {}
    table.insert(lines, acs("@CGroup Name: @w".. gt.groupname .."  @CLeader:@w" .. gt.leader))
    if isGroupCompact() then
        table.insert(lines, "-LVL-----PLAYER----------HP-----------MANA------")
    else
        table.insert(lines, "-LVL-----PLAYER----------HP-----------MANA---------TNL---ALIGN---QT-")
    end

    for _,member in ipairs(gt.members) do
        local name = member.name or "Unknown"
        local lvl = tonumber(member.info.lvl) or 0
        local hp = tonumber(member.info.hp) or 0
        local mn = tonumber(member.info.mn) or 0
        local mv = tonumber(member.info.mv) or 0
        local mhp = tonumber(member.info.mhp) or 0
        local mmn = tonumber(member.info.mmn) or 0
        local mmv = tonumber(member.info.mmv) or 0
        local tnl = tonumber(member.info.tnl) or 0
        local here = member.info.here or 0
        local align = tonumber(member.info.align) or 0
        local qt = member.info.qt or 0
        
        lvl = acs(string.format("@G[@Y%3s@G]", lvl))
        if here == "1" then here = acs("@W*") else here = " " end
        local namecolor = "@G"
        if name == "Iliad" then namecolor = "@W" end
        name = acs(namecolor)..name
        local hpcolor = "@G"
        if hp < mhp * 0.25 then hpcolor = "@R" elseif hp < mhp * 0.5 then hpcolor = "@Y" end
        if mhp > 100000 then mhp = "100k" end
        hp = acs(hpcolor)..string.format("%6s/%6s", hp, mhp)
        local mncolor = "@G"
        if mn < mmn * 0.25 then mncolor = "@R" elseif mn < mmn * 0.5 then mncolor = "@Y" end
        if mmn > 100000 then mmn = "100k" end
        mn = acs(mncolor)..string.format("%5s/%5s", mn, mmn)
        local aligncolor = "@w"
        if align < -800 then aligncolor = "@R"
        elseif align > 800 then aligncolor = "@W" end
        align = string.format("%s%5s", acs(aligncolor), align)

        local output =
            strpad(lvl,  5, "right") .. " " ..
            strpad(name, 11, "right") ..
            strpad(here, 1) .. " " ..
            acs("@G[") .. strpad(hp, 13) .. acs("@G] ") ..
            acs("@G[") .. strpad(mn, 11) .. acs("@G] ")
        if not isGroupCompact() then
            output = output ..
                acs("@G[@C") .. strpad(tostring(tnl), 4, "right") .. acs("@G] ") ..
                acs("@G[") .. strpad(align,            5) .. acs("@G] ") ..
                acs("@G[") .. strpad(tostring(qt),     2, "right") .. "]"
        end
        output = output .. acs("@w")
        table.insert(lines, output)
    end

    -- Skip redraw entirely if nothing changed
    local renderKey = table.concat(lines, "\n")
    if renderKey == lastRenderKey then
        return
    end
    lastRenderKey = renderKey

    rune.pane.replace("group", renderKey)
end

function sortGroupInfo(gt)
    local members = gt.members or {}
    table.sort(members, function(a, b)
        local lvlA = tonumber(a.info.lvl) or 0
        local lvlB = tonumber(b.info.lvl) or 0
        if lvlA == lvlB then
            return (tonumber(a.info.mhp) or 0) > (tonumber(b.info.mhp) or 0)
        end
        return lvlA > lvlB
    end)
    gt.members = members
    return gt
end

rune.gmcp.on("group", function(data)
   groupInfo = sortGroupInfo(data)
   groupUpdate(groupInfo)
end)

rune.pane.create("group")
rune.alias.exact("tgroup", function()
   rune.pane.toggle("group")
end)
rune.alias.exact("group compact", function()
   local current = isGroupCompact()
   local newValue = not current
   rune.store.set("groupcompact", newValue)
   rune.dbg("Group compact mode: " .. tostring(newValue))
   groupUpdate(groupInfo or {groupname="", leader="", members={}})
   layout.setGroupCompact(newValue)
end)

