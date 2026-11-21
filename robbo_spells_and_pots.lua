needSpellup = true
spellstate = {}
recoveries = {}
spellstateKnown = false

require("aardrune/spells")
require("aardrune/recoveries")

local maledictions = {
    { name = "blindness", cast = "cure blind", incombat = true},
    { name = "curse", cast = "remove curse"},
    { name = "curse of sloth", cast = "remove curse"},
    { name = "disease", cast = "cure disease"},
    { name = "ego whip", cast = "ego boost"},
    { name = "green death", action = "herbal"},
    { name = "hex of entropy", cast = ""},
    { name = "hex of misfortune", cast = ""},
    { name = "hydra blood", action = "herbal"},
    { name = "kobold stench", action = "herbal"},
    { name = "poison", cast = "cure poison"},
    { name = "rainbow", disrupt = "rainbow"},
    { name = "raven scourge", action = "herbal"},
    { name = "raw flesh", disrupt = "raw"},
    { name = "rune of ix", disrupt = "rune"},
    { name = "soften", cast = "harden body"},
    { name = "weaken", cast = "cure weakness"}
    
}


function initializeSpellupPlugin()
   if char.status.state ~= nil then
      rune.send("slist")
   else
      rune.timer.after(5, function(ctx) initializeSpellupPlugin() end)
   end
end

function execSpellup(name)
    -- This function is called by the timer to cast spells or by just typing spellup
    -- It checks if the player is ready and casts spells accordingly
    if char.status.state == nil then
        rune.dbg("execSpellup: GMCP char.base is not initialized, skipping spellup.")
    end
    local charState = charState()
    
    if charState == "READY" and spellstateKnown == false then
        rune.dbg("Spell state not known, grabbing slist affected...")
        aliasSlist()
        return
    end

    if charState == "READY" and needSpellup or affectedByMalediction() then
        rune.echo(acs("@G>> Auto-casting spells...@w"))
        rune.send_raw("spellup learned")
        needSpellup = false
    end
    if charState == "READY" and char.base.subclass:lower() == "ninja" and recoveries[50] == nil then
       rune.dbg("Subclass is ninja, casting quickstab if not active...")
       rune.send_raw("quickstab")
    end
end

function aliasSpellup()
   rune.send_raw("spellup learned")
   execSpellup() 
end

function triggerAffOff(name, line, wildcards)
    -- Called when an affect wears off
    local spellNum = tonumber(wildcards[1])
    spellstate[spellNum] = nil
    spellName = spellname[spellNum] or "Unknown Spell"
    rune.dbg("Affect off: " .. spellName .. " ("..spellNum ..")")
    needSpellup = true
end

function triggerAffOn(name, line, wildcards)
    -- Called when an affect is added
    local spellNum = tonumber(wildcards[1])
    local spellName = spellname[spellNum] or "Unknown Spell"
    local duration = tonumber(wildcards[2])
    rune.dbg("Affect on: " .. spellName .. " ("..spellNum ..") with duration " .. duration)
    spellstate[spellNum] = duration
    -- Check if the spell is a malediction
    for _, malediction in ipairs(maledictions) do
        --rune.dbg("Checking for malediction: " .. malediction.name .. " against " .. spellname[spellNum])
        if spellName == malediction.name then
            rune.dbg("Malediction detected: " .. malediction.name)
            rune.send_raw("spouse Warning, affected by malediction: " .. malediction.name)
        end
    end

end

function getRecoveryDuration(recNum)
    -- Check if a recovery is active for the given spell number
    if recoveries[recNum] ~= nil then
        return recoveries[recNum]
    else
        return 0
    end
end

function getSpellDuration(spellNum)
    -- Check if a spell is active for the given spell number
    rune.dbg("Checking duration for spell number: " .. spellNum)
    if spellstate[spellNum] ~= nil then
        return spellstate[spellNum]
    else
        return 0
    end
end



function aliasSlist(name, line, wildcards)
    -- Alias to start the spell list
    rune.trigger.enable("trg_slist_start")
    rune.trigger.enable("trg_slist_end")
    rune.send_raw("slist affected")
end

function triggerSlistStart(name, line, wildcards)
    -- Start of spell list
    spellstate = {}
    rune.trigger.enable("trg_slist_entry")
    rune.trigger.disable("trg_slist_start")
end

function triggerSlistEnd(name, line, wildcards)
    -- Start of spell list
    rune.trigger.disable("trg_slist_entry")
    rune.trigger.disable("trg_slist_end")
    spellstateKnown = true
end

function triggerSlistRecStart(name, line, wildcards)
    -- Start of spell list
    recoveries = {}
    rune.trigger.enable("trg_slist_rec_entry")
end

function triggerSlistRecEnd(name, line, wildcards)
    -- Start of spell list
    rune.trigger.disable("trg_slist_rec_entry")
end

function triggerRecoveryOn(name, line, wildcards)
    -- Recovery line, means spellup may be needed
    recoverynum = tonumber(wildcards[1])
    duration = tonumber(wildcards[2])
    recoveries[recoverynum] = duration
end

function triggerRecoveryOff(name, line, wildcards)
    -- Recovery line, means spellup may be needed
    recoverynum = tonumber(wildcards[1])
    recoveries[recoverynum] = nil
end

function triggerSlistEntry(name, line, wildcards)
    -- Capture each spell in the spell list
    local spellNum = tonumber(wildcards[1])
    local spellName = wildcards[2]
    local target = tonumber(wildcards[3])
    local duration = tonumber(wildcards[4])
    local pctpracticed = tonumber(wildcards[5])
    local recovery = tonumber(wildcards[6])
    local stype = tonumber(wildcards[7])
    spellstate[spellNum] =  duration
end

function triggerSlistRecEntry(name,line,wildcards)
    local recNum = tonumber(wildcards[1])
    local spellName = wildcards[2]
    local duration = tonumber(wildcards[3])
    if duration == 0 then recoveries[recNum] = nil
    else recoveries[recNum] = duration end
end

function aliasDumpSaff(name, line, wildcards)
    -- Alias to dump the current spell state
    if spellstateKnown == false then
        rune.dbg("Spell state not known, grabbing slist affected...")
        aliasSlist()
        return
    end
    rune.dbg("Current spell state:")
    for spellNum, duration in pairs(spellstate) do
        local spellName = spellname[spellNum] or "Unknown Spell"
        rune.dbg("Spell: " .. spellName .. " (" .. spellNum .. "), Duration: " .. duration)
    end
end

function affectedByMalediction()
    -- Check if the player is affected by any maledictions
    if spellstateKnown == false then
        rune.dbg("Spell state not known, grabbing slist affected...")
        aliasSlist()
        return false
    end
    for affected, duration in pairs(spellstate) do
        for _, malediction in ipairs(maledictions) do
            if spellname[affected] then
                --rune.dbg("Checking for malediction: " .. malediction.name .. " against " .. spellname[affected])
                if spellname[affected] == malediction.name then
                    rune.dbg("Malediction detected: " .. malediction.name)
                    return true 
                end
            end
        end
    end
    return false
end

function aliasCureAll(name, line, wildcards)
    -- Check if affected by any maledictions and cure them
    if spellstateKnown == false then
        rune.dbg("Spell state not known, grabbing slist affected...")
        aliasSlist()
        return
    end
    for affected, duration in pairs(spellstate) do
        for _, malediction in ipairs(maledictions) do
            if spellname[affected] then
                --rune.dbg("Checking for malediction: " .. malediction.name .. " against " .. spellname[affected])
                if spellname[affected] == malediction.name then
                    if (charState() == "READY") or (charState() == "COMBAT" and malediction.incombat) then
                        rune.dbg("Curing malediction: " .. malediction.name)
                        if malediction.cast ~= nil then
                            Send("cast '" .. malediction.cast.."'")
                        elseif malediction.disrupt ~= nil then
                            Send("cast disrupt " .. malediction.disrupt)
                        elseif malediction.action ~= nil then
                            Send(malediction.action)
                        else
                            rune.dbg("No action defined for malediction: " .. malediction.name)
                        end
                    end
                end
            end
        end
    end
end

require("aardrune/aliases/spells_and_pots_aliases")
require("aardrune/triggers/spells_and_pots_triggers")
rune.timer.every(30,function(ctx)
   if rune.state.connected == true and char.base ~= nil then execSpellup() end
end)


initializeSpellupPlugin()