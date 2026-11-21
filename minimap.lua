local mapline = 0
local mapbuffer = {}

-- Strip ANSI escape sequences and count visible UTF-8 character width
local function visibleLen(s)
   local stripped = s:gsub("\027%[[%d;]*m", "")
   -- Count UTF-8 codepoints by skipping continuation bytes (0x80-0xBF)
   local _, count = stripped:gsub("[^\128-\191]", "")
   return count
end

function renderMinimap()
   rune.pane.clear("minimap")

   local startIdx = 1
   for i = 1, #mapbuffer do
      if visibleLen(mapbuffer[i]) > 0 then
         startIdx = i + 1
         break
      end
   end

   for i = startIdx, #mapbuffer do
      rune.pane.write("minimap", mapbuffer[i])
   end
end

rune.trigger.exact("<MAPSTART>", function()
   rune.trigger.enable("minimap_capture")
   mapline = 0
   mapbuffer = {}
end, {gag = true})

rune.trigger.exact("<MAPEND>", function()
   rune.trigger.disable("minimap_capture")
   renderMinimap()
end, {gag = true})

rune.trigger.regex("^(.*)$", function(matches,ctx)
   mapline = mapline + 1
   if mapline > 2 and mapline < 19 then
      table.insert(mapbuffer, ctx.line:raw())
   end
end, {gag = true, name="minimap_capture"})
rune.trigger.disable("minimap_capture")

rune.pane.create("minimap")
