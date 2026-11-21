clanRoster = {}
myClan = ''

gqDefaultMessages = {
    "Congratulations WINNER on a GQ victory!",
    "WINNER passes inspection in a flawless GQ victory!",
    "WINNER proves that training pays off with a GQ victory!"
}

gqCustomMessages = {
    ["Iliad"]  = "Iliad's bot goes to 11 in his fully automated GQ victory!",
    ["Madrox"] = "Madrox somehow wins a GQ without knitting at all, how?!?!",
    ["Saraid"] = "Saraid doesn't even stop knitting during her GQ win!"
}

function OnPluginInstall()
    if not IsConnected() then return end
    DoAfterSpecial(120, "initializeClanPlugin()",sendto.script)
end

function OnPluginConnect()
    DoAfterSpecial(120, "initializeClanPlugin()",sendto.script)
end

function initializeClanPlugin()
    myClan = getGMCP("char.base.clan")
    rune.send("updateroster")
end
    
function updateClanRoster(name, line, wildcards)
    rune.dbg("Updating clan roster for " .. myClan)
    rune.trigger.enable("trg_clan_roster_member")
    rune.trigger.enable("trg_clan_roster_end")
    Send("roster " .. myClan .. " 1")
end

function triggerClanRosterEnd(name, line, wildcards)
    rune.trigger.disable("trg_clan_roster_member")
    rune.trigger.disable("trg_clan_roster_end")
    rune.echo("Clan roster data updated.")
end

function triggerClanRosterMember(name, line, wildcards)
    -- Capture the clan member data
    local member = wildcards[1]
    -- Add to the clan roster
    table.insert(clanRoster, member)
end

function triggerGQWinner(name, line, wildcards)
    -- Capture the GQ winner
    local winner = wildcards[1]
    local wincount = wildcards[2]
    if table.contains(clanRoster, winner) then
        -- Check if we have a custom message for this winner
        local message = gqCustomMessages[winner] or gqDefaultMessages[math.random(#gqDefaultMessages)]
        -- Replace WINNER in the message with the actual winner's name
        message = message:gsub("WINNER", winner)
        message = "@CRobbot Announce: $C" .. message
        message = message .. " @c(@cTotal wins: @C" .. wincount .. "@c)$C"
        
        -- Send the congratulatory message
        robbotSend("clan",message)
    end
end

function triggerClanOutcast(name,line,wildcards)
    -- Capture the outcast member
    local outcast = wildcards[1]
    if table.contains(clanRoster, outcast) then
        -- Remove from the roster
        for i, member in ipairs(clanRoster) do
            if member == outcast then
                table.remove(clanRoster, i)
                break
            end
        end
    end
end