local autonoexp = tonumber(rune.store.get("autonoexp")) or 0
local questCompleted = 0
cpState = nil
cpNextLevel = 0
local initialized = false
noexp = false
local roomPreviousNum = 0
local roomPreviousZone = 0
local questStartTime = nil

questmob = ''
questroom = ''
questzone = ''

homeroom = rune.store.get("movement_homeroom")
if homeroom == nil then
    rune.echo("Robbo_Quest: No home room number set. Type 'sethome <room number>' to set it.")
    homeroom = 0 -- Default to 0 if not set
end

function initializeQuestPlugin()
   if char.status.state ~= nil then
     rune.dbg("Quest plugin: Initilizing campaign state.")
     rune.echo("Robbo_Quest: Campaign autonoexp is: " .. (autonoexp and "enabled" or "disabled"))
     rune.send_raw("cp check")
     rune.gmcp.send("config noexp")
     initialized = true
     roomPreviousNum = tostring(room.info.num) 
     roomPreviousZone = room.info.zone
     checkCampaignNoExp()
   else rune.timer.after(5, function(ctx) initializeQuestPlugin() end)
   end
end

rune.gmcp.on("char.status", function(data)
   checkCampaignNoExp()
end, {priority = 100})

rune.gmcp.on("room.info",function(data)
   if data.num == homeroom and questCompleted == 1 then
   -- We are in the homeroom and the quest is completed
   rune.send_raw("quest complete")
   questCompleted = 0 -- Reset the quest completion flag
   end
end)

rune.gmcp.on("config.noexp",function(data)
   -- Looking for GMCP handler updates for return to home
   -- On any update, check campaign state
   local noexpState = data
   if noexpState == "YES" then
      noexp = true
   else
      noexp = false
   end
    if autonoexp then
        checkCampaignNoExp()
    end
end)

rune.gmcp.on("comm.quest",function(data)
    if data.action == "start" then
        questmob = data.targ
        questroom = data.room
        questzone = data.area
        questStartTime = os.time()

        rune.echo("Quest started: Target: " .. questmob .. ", Room: " .. questroom .. ", Area: " .. questzone)
        onquest = true
        setActivity("quest", true)
        smartScanKeywords = nil
        rune.echo("Checking the mob database for most likely room...")
        local targetRooms = findQmobBestRoom(questmob, questroom, questzone)
        rune.dbg("Returned from findQmobBestRoom: " .. tostring(targetRooms))
        if targetRooms == nil then
           rune.echo("asking GMCP Mapper plugin to find the quest room: " .. questroom .. " in area: " .. questzone)
           targetRooms = findRoomExact(questroom, questzone)
        end
        if targetRooms ~= nil then
           setGowhereRoomIDs(targetRooms)
        end
    elseif data.action == "fail" then
       questmob = ''
       questroom = ''
       questzone = ''
       onquest = false
       setActivity("quest", false)
       clearQmob()
       qtime = 15
        questStartTime = nil
        ColourNote("brightred", "black", "Quest FAILED!")
     elseif data.action == "comp" then
         local elapsed = ""
         if questStartTime then
            local secs = os.time() - questStartTime
            local mins = math.floor(secs / 60)
            local rem = secs % 60
            elapsed = string.format("%dm %02ds", mins, rem)
         end

         local rewards = {}
         if data.qp and data.qp > 0 then table.insert(rewards, "QP:" .. data.qp) end
         if data.tierqp and data.tierqp > 0 then table.insert(rewards, "Tier:" .. data.tierqp) end
         if data.hardcore and data.hardcore > 0 then table.insert(rewards, "Hardcore:" .. data.hardcore) end
         if data.opk and data.opk > 0 then table.insert(rewards, "OPK:" .. data.opk) end
         if data.lucky and data.lucky > 0 then table.insert(rewards, "Lucky:" .. data.lucky) end
         if data.double and data.double > 0 then table.insert(rewards, "Double:" .. data.double) end
         if data.daily and data.daily > 0 then table.insert(rewards, "Daily:" .. data.daily) end
         if data.pracs and data.pracs > 0 then table.insert(rewards, "Pracs:" .. data.pracs) end
         if data.trains and data.trains > 0 then table.insert(rewards, "Trains:" .. data.trains) end
         if data.tp and data.tp > 0 then table.insert(rewards, "TP:" .. data.tp) end
         if data.gold and data.gold > 0 then table.insert(rewards, "Gold:" .. data.gold) end

          local msg = ""
          msg = msg .. "@GQuest COMPLETE!"
          if elapsed ~= "" then
             msg = msg .. "@C Time:" .. elapsed
          end
          if data.totqp then
             msg = msg .. "@Y Total:" .. data.totqp
          end
          if #rewards > 0 then
             msg = msg .. "@w [" .. table.concat(rewards, ", ") .. "]"
          end
          if data.completed then
             msg = msg .. "@M (Total:" .. data.completed .. ")"
          end
          rune.echo(acs(msg .. "@w"))

         questmob = ''
         questroom = ''
         questzone = ''
         onquest = false
         setActivity("quest", false)
         questStartTime = nil
         qtime = 30
    end
end)

function triggerAutoTick(name, line, wildcards)
    qtime = wildcards[1] or 0
    -- TBD Will need to sort out later
end

function questMobKilled(name,line,wildcards)
    -- Quest mob has been killed
    rune.dbg("Quest mob killed: " .. line)
    questCompleted = 1
    clearQmob()
end

function triggerQuestTime(name, line, wildcards)
    -- Triggered when it's time to quest again
    rune.send_raw("spouse @C--> @YQUEST TIME!! @C<--@w")
    -- For later, we'll add an option for sound alerts
end

function aliasQuest(name,line,wildcards)
    -- This function covers various quest-related commands)
    if name == "alias_questrequest" then
        -- Handle quest request
        rune.send_raw("quest request")
    elseif name == "alias_questinfo" then
        -- Handle quest info
        rune.send_raw("quest info")
    elseif name == "alias_questcomplete" then
        if questCompleted == 0 then
            rune.echo("Your quest is not completed yet. Please kill the quest mob first.")
            return
        end
        -- Handle quest completion
        if charState() ~= "READY" then
            rune.echo("You're a little busy for to quest complete. Current state: " .. charState())
            return
        else
            if tostring(room.info.num) ~= tostring(homeroom) then
                rune.send("mapper goto " .. homeroom)
            else
                rune.send_raw("quest complete")
            end
        end
    end
end

function triggerCampaignRemaining(name,line,wildcards)
    cpState = "inprogress"
end

function triggerCampaignAvailable(name,line,wildcards)
    if cpState ~= "inprogress" then cpState = "available" end
    rune.dbg("Campaign State: "..cpState)
    cpNextLevel = tonumber(char.status.level)
    initialized = true
end

function triggerCampaignNeedLevel(name,line,wildcards)
    if cpState ~= "inprogress" then cpState = "needlevel" end
    rune.dbg("Campaign State: "..cpState)
    cpNextLevel = tonumber(char.status.level) + 1
    initialized = true
end

function triggerCampaignComplete(name,line,wildcards)
    cpState = "needlevel"
    rune.dbg("Campaign State: "..cpState)
    setActivity("cp", false)
    initialized = true
    --CallPlugin(mobdbPluginID,"ClearCPGQWin()")
end

function triggerCampaignStart(name,line,wildcards)
    cpState = "inprogress"
    cpNextLevel = tonumber(char.status.level) + 1
    setActivity("cp", true)
    if noexp then
        -- If noexp is on, turn it off
        rune.echo("Campaign started, turning off noexp.")
        rune.gmcp.send("config noexp off")
        noexp = false
    end
    initialized = true
end

function aliasAutoNoExp(name,line,wildcards)
    local expset = tonumber(wildcards[1])
    if expset == nil or expset == 0 then
        rune.echo("Disabling auto-noexp for campaigns.")
        autonoexp = 0
        rune.store.set("autonoexp", "false")
    else
        rune.echo("Enabling auto-noexp for Campaigns when you have "..expset.." experience points to level.")
        autonoexp = expset
        rune.store.set("autonoexp", tostring(expset))
    end
end

function checkCampaignNoExp()
    -- This is run frequently on gmcp updates to see if we need to turn on noexp, this only is called if autonoexp is set
    local tnl = tonumber(char.status.tnl)
    local currentLevel = tonumber(char.status.level)
    --rune.dbg("Currentlevel is: "..tostring(currentLevel).." cpNextLevel is:"..tostring(cpNextLevel))
    if cpState == "available" or (cpState == "inprogress" and cpNextLevel <= currentLevel) then
        -- Campaign is available or in progress + taken at this level
        if autonoexp > 0 and tnl <= autonoexp and noexp==false then
            rune.gmcp.send("config noexp on")
            noexp = true
            rune.echo("Campaign is available, turning on noexp as TNL is: " .. tnl)
        end
    end
end

function dumpCPState(name,line,wildcards)
    -- Debugging function to dump the current campaign state
    rune.echo("Campaign State: " .. tostring(cpState))
    rune.echo("Next Level: " .. tostring(cpNextLevel))
    rune.echo("Current Level: " .. tostring(char.status.level))
    rune.echo("Autonoexp: " .. tostring(autonoexp))
end

require("aardrune/aliases/quest_aliases")
require("aardrune/triggers/quest_triggers")


initializeQuestPlugin()