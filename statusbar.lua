local vitals = {}
tickremaining = 30
rune.gmcp.on("comm.tick", function()
   tickremaining = 30
end)

rune.timer.every(1,function()
   tickremaining = tickremaining - 1
end)

function drawalign(value, width)
    local bg
    local fg = 30 -- black text

    -- Select background based on alignment
    if value < -800 then
        bg = 41       -- red
        fg = 37       -- white text on red
    elseif value > 800 then
        bg = 47       -- white
    else
        bg = 100      -- grey
    end

    local text = "Align: "..tostring(value)

    -- Center the value in the bar
    local left = math.floor((width - #text) / 2)
    local right = width - #text - left

    return "[" ..
        ANSI(bg) .. ANSI(fg) ..
        string.rep(" ", left) ..
        text ..
        string.rep(" ", right) ..
        ANSI(0) ..
        "]"
end

rune.ui.bar("vitals", function(width)
    local hp, mhp = tonumber(char.vitals.hp) or 0, tonumber(char.maxstats.maxhp) or 1
    if not (hp and mhp) then return "" end
    local mn, mmn = tonumber(char.vitals.mana) or 0, tonumber(char.maxstats.maxmana) or 1
    local mv, mmv = tonumber(char.vitals.moves) or 0, tonumber(char.maxstats.maxmoves) or 1
    local tnl, maxtnl = tonumber(char.status.tnl) or 0, tonumber(char.base.perlevel) or 1
    local hp_color = hp < mhp * 0.25 and rune.style.red or rune.style.green
    local qts = tostring(qtime)
    if tonumber(qtime) == 0 then qts = acs("@R"..tostring(qtime).."@w") end
    local tickr = tostring(tickremaining)
    if tickremaining < 5 then tickr = acs("@Y"..tostring(tickremaining).."@w") end
    local kq = #killqueue or 0
    local lv = tonumber(char.status.level) or 0
    local epct = tonumber(char.status.enemypct) or 0
    local cpi = cpIndex or 0
    local gqi = gqIndex or 0
    local tnlcolor = 100
    if tostring(noexp) == "true" then tnlcolor = 41 end
    return string.format(" %s %s %s %s %s %s %s %s %s %s %s",
        drawbar("HP", hp, mhp, 42, 43, 41, 24),
        drawbar("MN", mn, mmn, 46, 43, 41, 24),
        drawbar("MV", mv, mmv, 45, 43, 41, 24),
		drawalign(tonumber(char.status.align or 0),14),
		drawbar("LV: "..lv.." TNL", tnl, maxtnl, tnlcolor, tnlcolor, tnlcolor, 24, true),
		drawbar("Enemy", epct, 100, 43, 43, 43, 20),
		"KQ: "..kq,
		"CP#: "..cpi,
		"GQ#: "..gqi,
		"QT: "..qts,
		"Tick: "..tickr
		
        )
end)

local green, yellow, gray, dim, inverse =
    rune.style.green, rune.style.yellow, rune.style.gray,
    rune.style.dim, rune.style.inverse

-- Render completion bar when cycling through matches
local function render_completion_bar(width)
    local comp = rune.completion.state
    local parts = {}

    for i, match in ipairs(comp.matches) do
        if i == comp.index then
            -- Current selection: inverse (highlighted)
            parts[#parts + 1] = inverse(match)
        else
            -- Other options: dimmed
            parts[#parts + 1] = dim(match)
        end
    end

    local left = table.concat(parts, " ")
    local right = dim("(" .. comp.index .. "/" .. #comp.matches .. ")")

    return { left = left, right = right }
end

-- Ctrl+C double-tap quit state
local quit_pending = false

    
rune.ui.bar("aardstatus", function(width)
    -- Check if we should show completion bar instead (only when cycling with multiple matches)
    local comp = rune.completion and rune.completion.state
    if comp and comp.original and #comp.matches > 1 then
        return render_completion_bar(width)
    end

    local state = rune.state

    -- Left side: connection status (or quit warning)
    local left
    if quit_pending then
        left = yellow("Press Ctrl+C again to exit")
    elseif state.connected then
        left = green("●") .. " " .. gray(state.address)
    else
        left = gray("●") .. " " .. gray("Disconnected")
    end

    local activity = getActivity()
    local qdata = ''
    if activity == "quest" then
        if questmob == nil then questmob = '' end
        if questroom == nil then questroom = '' end
        if questzone == nil then questzone = '' end
        qdata = acs("@Gqmob: @c".. questmob .."@G loc: @c"..questroom .."@G (@c".. questzone.."@G)@w")
    elseif activity == "gq" then
        local gqmob = getCurrentGQMob()
        if gqmob then
            qdata = acs("@Mgq: @c".. tostring(gqmob.quantity) .. " " .. tostring(gqmob.name) .."@M (@c".. tostring(gqmob.location) .."@M)@w")
        end
    elseif activity == "cp" then
        local cpmob = getCurrentCPMob()
        if cpmob then
            qdata = acs("@Ccp: @c".. tostring(cpmob.name) .."@c (@c".. tostring(cpmob.location) .."@c)@w")
        end
    end
    
    
    -- Right side: scroll mode indicator
    local right
    if state.search_active then
        right = yellow("SEARCH")
    elseif state.scroll_mode == "scrolled" then
        right = yellow("SCROLL") .. " " .. dim("(" .. state.scroll_lines .. " new)")
    else
        right = dim("LIVE")
    end
    

    local center
    
    return { left = left.."  "..qdata, center = center, right = right }
end)

