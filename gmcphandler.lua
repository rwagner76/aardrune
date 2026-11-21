rune.gmcp.subscribe("Char")
rune.gmcp.subscribe("Room")
rune.gmcp.subscribe("Group")

if char == nil then
   char = {}
   char.vitals = {}
   char.base = {}
   char.status = {}
   char.stats = {}
   char.maxstats = {}
   char.worth = {}
end

if group == nil then
   group = {}
end

if config == nil then config = {} end

rune.hooks.on("gmcp", function(package, data, raw)
    --rune.dbg(package .. " " .. tostring(raw))
end)

if char == nil then char = {} end

rune.gmcp.on("char.vitals", function(data)
    char["vitals"] = data
    rune.ui.refresh_bars()
end)

rune.gmcp.on("char.status", function(data)
    char["status"] = data
    rune.ui.refresh_bars()
end)

rune.gmcp.on("char.base", function(data)
    char["base"] = data
    rune.ui.refresh_bars()
end)

rune.gmcp.on("char.stats", function(data)
    char["stats"] = data
end)

rune.gmcp.on("char.maxstats", function(data)
    char["maxstats"] = data
end)

rune.gmcp.on("char.worth", function(data)
    rune.dbg("char.worth GMCP received: " .. serialize.save_simple(data))
    char["worth"] = data
end)


rune.gmcp.on("group", function(data)
    group = data
end)
