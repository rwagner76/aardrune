mobsinRoom = {}
lastCharState = "READY"
qaDefault = '' -- Default mob keywords to attack for combat alias
qiID = nil
local initialized = false
attackskill = rune.store.get("combat_attackskill") or "kick"
preferredAlignment = rune.store.get("combat_preferred_alignment") or "neutral"
killallLowerLevel = rune.store.get("combat_killall_lowerlevel") or 5
killallHigherLevel = rune.store.get("combat_kalower") or 15
killcommand = rune.store.get("combat_killcommand") or "kill"
mobdied = true
backstabbin = false
midround = rune.store.get("combat_midround") or false
oldroom = 0


function aliasCombatHelp(name, line, wildcards)
    rune.echo("Combat Commands")
    rune.echo("------------------------------------------------------------")
    rune.echo("Attacking:")
    rune.echo("  qa [keywords]       - Queue attack on mob (blank = repeat last target)")
    rune.echo("  ka                  - Kill all mobs in room matching level/align criteria")
    rune.echo("  cq                  - Clear the kill queue")
    rune.echo("  cs                  - Combat stab (backstab + spiral loop while in combat)")
    rune.echo("")
    rune.echo("Settings:")
    rune.echo("  pa <align>          - Set preferred alignment to fight (good/evil/neutral)")
    rune.echo("  preferredalign <a>    (long form)")
    rune.echo("  kamax <n>           - Killall: only target mobs up to <n> levels above you")
    rune.echo("  killall max <n>       (long form)")
    rune.echo("  kamin <n>           - Killall: only target mobs up to <n> levels below you")
    rune.echo("  killall min <n>       (long form)")
    rune.echo("  as <skill>          - Set attack skill (e.g. 'kick', 'spiral')")
    rune.echo("  attackskill <skill>   (long form)")
    rune.echo("  as                  - Execute the currently set attack skill")
    rune.echo("  killcommand <cmd>   - Set the kill command (default: 'kill')")
    rune.echo("")
    rune.echo("Misc:")
    rune.echo("  look                - Look (clears mob room cache and kill queue)")
    rune.echo("------------------------------------------------------------")
end


function aliasPreferredAlign(name, line, wildcards)
    -- Set the preferred alignment for combat
    local newAlign = wildcards[2]:lower()
    if newAlign == "good" or newAlign == "evil" or newAlign == "neutral" then
        preferredAlignment = newAlign
        rune.store.set("combat_preferred_alignment", preferredAlignment)
        rune.dbg("Preferred alignment set to: " .. preferredAlignment)
    else
        rune.echo("Invalid alignment specified. Use 'good', 'evil', or 'neutral'.")
    end
end 

rune.gmcp.on("room.info", function(data)
   if oldroom ~= data.num then
      -- Clear the mobs in the room when the room changes
      mobsinRoom = {}
      killqueue = {}
      --BroadcastPlugin(2,"") -- Broadcast the kill queue
      rune.dbg("Room changed, clearing mob cache and kill queue.")
      if charState() ~= "COMBAT" then
         mobdied = true
         backstabbin = false
      end
   end
end)

rune.gmcp.on("char.status", function(data)
   if tostring(char.status.state) ~= "8" then
       local t = rune.timer.get("midround_timer")
       if t ~= nil then t:remove() end
   end
end)

function aliasLook(name,line,wildcards)
    -- If we look, we want to clear the mobs in the room
        mobsinRoom = {}
        killqueue = {}
        --BroadcastPlugin(2,"") -- Broadcast the kill queue
        rune.send_raw("look")
end

function mobLevelOK(mob)
    -- Check if the mob's level is within the acceptable range
    local mylevel = tonumber(char.status.level)
    if mob.level < mylevel - killallLowerLevel or mob.level > mylevel + killallHigherLevel then
        rune.dbg("Mob level not OK: " .. mob.name .. " (level: " .. mob.level .. ", my level: " .. mylevel .. ")")
        return false
    end
    rune.dbg("Mob level OK: " .. mob.name .. " (level: " .. mob.level .. ", my level: " .. mylevel .. ")")
    return true
end

function mobAlignOK(mob)
    local alignNumber = tonumber(char.status.align)
    local myAlign = "neutral"
    if mob.align == "neutral" then return true end
    if alignNumber < -800 then myAlign = "evil"
    elseif alignNumber > 800 then myAlign = "good"
    end
    rune.dbg("My alignment: " .. myAlign .. ", Mob alignment: " .. mob.align .. ", Preferred alignment: " .. preferredAlignment)
    if preferredAlignment == "good" and myAlign == "good" and mob.align == "evil" then return true end
    if preferredAlignment == "evil" and myAlign == "evil" and mob.align == "good" then return true end
    if preferredAlignment == "neutral" and myAlign == "good" and mob.align == "good" then return true end
    if preferredAlignment == "neutral" and myAlign == "evil" and mob.align == "evil" then return true end
    if preferredAlignment == "neutral" and myAlign == "neutral" then return true end
    return false

end    

function killAll(name,line,wildcards)
    if charState() ~= "READY" then
        rune.echo("You're a bit busy right now. State = " .. charState() .. ".")
        return
    end
    rune.dbg("Killing all mobs in the room that match criteria. Mobs in kill queue: " .. #killqueue)
    if #killqueue == 0 then
        for _, mob in ipairs(mobsinRoom) do 
            rune.dbg("Checking mob: " .. mob.name .. " (" .. mob.keywords .. ")")
            if mobLevelOK(mob) and mobAlignOK(mob) then
                rune.dbg("Adding mob to kill queue: " .. mob.name .. " (" .. mob.keywords .. ")")
                table.insert(killqueue, mob.keywords)
                --BroadcastPlugin(2,table.concat(killqueue, "|")) -- Broadcast the kill queue
            else
                rune.dbg("Mob does not match criteria: " .. mob.name .. " (level: " .. mob.level .. ", align: " .. mob.align .. ")")
            end
        end
    end
    if #killqueue > 0 and charState() == "READY" then
        local mobkw = table.remove(killqueue, 1)
        --BroadcastPlugin(2,table.concat(killqueue, "|")) -- Broadcast the kill queue
        rune.dbg("Killing the first mob in the queue, keywords: " .. mobkw)
        rune.send_raw(killcommand.." '".. mobkw .. "'")
    else
        rune.echo("No mobs in the room match the criteria for killing.")
    end
    mobsinRoom = {}
end

    
function captureQmobKeywords(name, line, wildcards)
    -- Capture the keywords of a quest mob when seen
    -- This is called by the trg_questmob_seen trigger
    qmobKeywords = wildcards[1]
    rune.dbg("Captured quest mob keywords: " .. qmobKeywords)
end

function aliasQueueAttack(name, line, wildcards)
    -- Alias to queue an attack on a mob. The default target will be a quest mob that has been seen.
    -- Uses the captured keywords from trg_questmob_seen
    local mobKeywords = wildcards[1]
    if mobKeywords == nil or mobKeywords == "" then
        -- If no keywords provided, use the default (either quest mob or the last mob we attacked)
        mobKeywords = qaDefault
    end
    local command = killcommand.." ".. mobKeywords
    --BroadcastPlugin(1,mobKeywords) -- Broadcast Targetted mob
    if charState() == "READY" then
        -- If the character is ready, send the attack command immediately
        setQATarget(mobKeywords) -- If we attack one, we just need to type qa to attack another of the same keywords
        rune.send_raw(command)
    elseif charState() == "COMBAT" then
        -- If not ready, add to kill queue
        rune.dbg("Character already fighting, adding to kill queue: " .. mobKeywords)
        table.insert(killqueue, mobKeywords)
        --BroadcastPlugin(2,table.concat(killqueue, "|")) -- Broadcast the kill queue
    else
        -- If in another state, just send the command
        rune.dbg("Character not in a good state, ignoring.")
    end
end

function addtoMobTable(level,name,keywords,alignment)
    -- Capture mobs in the room
    -- This is called by the trg_mobinroom trigger

    local mobtable = {
        ["level"] = tonumber(level),
        ["name"] = name,
        ["keywords"] = keywords,
        ["align"] = alignment
    }
    table.insert(mobsinRoom, mobtable)
end

function setQATarget(keywords,id)
    -- Set the quest mob keywords to attack
    qaDefault = keywords
    qaID = id or nil
    rune.dbg("COMBAT: QA attack keywords set to: " .. qaDefault .. " ID: "..tostring(qaID))
end

function setKillAllMin(name,line,wildcards)
    -- Set the lower level limit for killall
    local newMin = tonumber(wildcards[2])
    if newMin == nil or newMin < 0 then
        rune.echo("Invalid minimum level specified. Please provide a positive number.")
        return
    end
    rune.store.set("combat_killall_lowerlevel", newMin)
    killallLowerLevel = newMin
    rune.echo("COMBAT: Minimum level for killall set to your level minus " .. newMin .. " levels.")
end

function setKillAllMax(name,line,wildcards)
    -- Set the higher level limit for killall
    local newMax = tonumber(wildcards[2])
    if newMax == nil or newMax < 0 then
        rune.echo("Invalid maximum level specified. Please provide a positive number.")
        return
    end
    rune.store.set("combat_killall_higherlevel", newMax)
    killallHigherLevel = newMax
    rune.echo("COMBAT: Maximum level for killall set to your level plus " .. newMax .. " levels.")
end

function clearKillAllQueue()
    -- Clear the kill queue
    killqueue = {}
    --BroadcastPlugin(2,"") -- Broadcast the kill queue
    rune.echo("COMBAT: Kill queue cleared.")
end

function setAttackSkill(name, line, wildcards)
    -- Set the attack skill to use
    local newSkill = wildcards[2]
    if newSkill == nil or newSkill == "" then
        rune.echo("Invalid attack skill specified. Please provide a valid skill name.")
        return
    end
    rune.store.set("combat_attackskill", newSkill)
    attackskill = newSkill
    rune.echo("COMBAT: Attack skill set to: " .. attackskill)
end

function doAttackSkill(name, line, wildcards)
    -- Execute the attack skill
    if charState() ~= "COMBAT" then
        rune.echo("You are not in combat. Please enter combat before using an attack skill.")
        return
    end
    if attackskill == nil or attackskill == "" then
        rune.echo("No attack skill set. Please use 'setattack <skill>' to set it.")
        return
    end
    local mobkw = wildcards[1]
    rune.send_raw(attackskill)
    if midround == true and rune.timer.get("midround_timer") == nil then
       rune.timer.every(2.5,function()
          rune.send_raw(attackskill)
       end, {name = "midround_timer"})
    end
end

function aliasMidround(args)
   rune.dbg("Midround arg: "..tostring(args[1]))
   if args[1] == "on" then midround = true
   elseif args[1] == "off" then midround = false
   else midround = not midround end
   if midround == true then rune.echo("Combat: Midround attack enabled")
       else rune.echo("Combat: Midround attack disabled") end
   rune.store.set("combat_midround",midround)
end

function setKillCommand(name, line, wildcards)
    -- Set the command to use for killing mobs
    local newCommand = wildcards[1]
    rune.store.set("combat_killcommand", newCommand)
    killcommand = newCommand
    rune.echo("COMBAT: Kill command set to: " .. killcommand)
end 

function aliasCombatStab(name, line, wildcards)
    -- We'll enable a trigger to fire on battle prompts. If mob died since last one, we'll stab.
    if backstabbin == true then
        rune.echo("Already combat stabbing, ignoring...")
        return
    end
    backstabbin = true
    mobdied = true
    execCombatStab()
end

function execCombatStab()
    if charState() ~= "COMBAT" then
        rune.dbg("Not in combat.")
        return
    end
    if mobdied then
        rune.send_raw("bs")
        local rc,quickStabDuration = CallPlugin(spellupPluginID,"getSpellDuration",601)
        --rune.dbg("Quickstab duration time: " .. quickStabDuration)
        if quickStabDuration > 0 then rune.send("as") end
        mobdied = false
    else
        rune.send("as")
    end
    rune.timer.after(3,function(ctx) execCombatStab() end)
end


function triggerExpGained(name,line,wildcards)
    rune.dbg("Mob died, setting mobdied to true.")
    mobdied = true
end

require("aardrune/triggers/combat_triggers")
require("aardrune/aliases/combat_aliases")
