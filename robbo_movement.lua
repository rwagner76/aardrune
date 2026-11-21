-- MUSHClient Lua script for Robbo's Movement Plugin

local movement_homeroom
local equippedportal

function initializeMovementPlugin()
    movement_homeroom = rune.store.get("movement_homeroom")
    if movement_homeroom == nil then
        rune.echo("No home room number set. Type 'sethome <room number>' to set it.")
    end

    equippedportal = rune.store.get("movement_equippedportal")
    if equippedportal == nil then
        equippedportal = "robboamulet"
        rune.store.set("movement_euippedportal", equippedportal)
    end
end

function aliasSetHome(name,line,wildcards)
    -- Set the home room number
    local roomNumber = tonumber(wildcards[1])
    if not roomNumber then
        rune.echo("Invalid room number. Please provide a valid number.")
        return
    end
    rune.store.set("movement_homeroom", roomNumber)
    movement_homeroom = roomNumber
    rune.echo("Home room set to " .. roomNumber .. ".")
end

function aliasGowhere(name,line,wildcards)
    -- Annoying, but necessary alias to send "gowhere" command instead of 'go' (goals)
    rune.send_raw("gowhere")
end

function aliasArun(name,line,wildcards)
    -- Alias to run to a the first room the first found area
    rune.trigger.enable("trg_areasearch_stg1",true)
    local query = wildcards[1]
    if query:find("darkside") then
        query = "darkside"
    end
    rune.send_raw("map find area " .. query)
end

function areaSearchHeader(name,line,wildcards)
    -- Header for area search results
    -- This is called by the trg_areasearch_stg1 trigger
    rune.trigger.enable("trg_areasearch_stg2")
    rune.trigger.disable("trg_areasearch_stg1")
end

function areaSearchMatch(name,line,wildcards)
    -- Header for area search results
    -- This is called by the trg_areasearch_stg1 trigger
    rune.trigger.enable("trg_areasearch_stg2",false)
    local id = wildcards[1]
    local keyword = wildcards[2]
    local fullname = wildcards[3]
    rune.dbg("Running to area: ".. fullname .. " (Keyword: " .. keyword .. ")")
    rune.send_raw("map goto "..keyword)
end

function aliasGraveYard(name, line, wildcards)
   local gymobs = {
      skeleton = {28919, 28927, 28941},
      zombie = {28923, 28929, 28943},
      ghost = {28925, 28935},
      ghoul = {28931, 28945},
      ghast = {28933, 28947},
      wight = {28937},
      wraith = {28939}
   }

   local search = wildcards[1]
   if not search or search == "" then
      rune.echo("Usage: graveyard <mob search string>")
      return
   end
   search = search:lower()

   local rooms = {}
   for mob, roomList in pairs(gymobs) do
      if mob:find(search, 1, true) then
         for _, room in ipairs(roomList) do
            table.insert(rooms, tostring(room))
         end
      end
   end

   if #rooms == 0 then
      rune.echo("No graveyard mobs matching '" .. search .. "'.")
      return
   end

   for _, room in ipairs(rooms) do
      setPendingSpeedwalk(room, "rip")
   end
   queueGowhereRooms(rooms)
   rune.echo("Graveyard run: " .. #rooms .. " rooms queued for '" .. search .. "'.")
   rune.send("mapper goto " .. rooms[1])
end


require("aardrune/aliases/movement_aliases")

initializeMovementPlugin()