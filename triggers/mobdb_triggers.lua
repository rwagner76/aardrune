rune.trigger.regex("^{roomchars}$", function(matches, ctx)
    return startRoomChars("trg_start_roomchars", ctx.line, matches)
end, {name = "trg_start_roomchars", priority = 10, gag = true})

rune.trigger.regex("^{/roomchars}$", function(matches, ctx)
    return endRoomChars("trg_end_roomchars", ctx.line, matches)
end, {name = "trg_end_roomchars", priority = 10, gag = true})

rune.trigger.regex("^{roomobjs}$", function(matches, ctx)
    return nil
end, {name = "trg_start_roomobjs", priority = 10, gag = true})

rune.trigger.regex("^{/roomobjs}$", function(matches, ctx)
    return nil
end, {name = "trg_end_roomobjs", priority = 10, gag = true})

rune.trigger.regex("^You still have to kill \\* (.+) \\((.+)\\)$", function(matches, ctx)
    triggerCampaignTarget("trg_campaign_target", ctx.line, matches)
end, {name = "trg_campaign_target", priority = 100})

rune.trigger.regex("^You have .+ left to finish this campaign.$", function(matches, ctx)
    triggerCampaignCheckEnd("trg_campaign_check_end", ctx.line, matches)
end, {name = "trg_campaign_check_end", priority = 100})

rune.trigger.regex("^You still have to kill (\\d) \\* (.+) \\((.+)\\)$", function(matches, ctx)
    triggerGQTarget("trg_gq_target", ctx.line, matches)
end, {name = "trg_gq_target", priority = 100})

rune.trigger.regex("^You can", function(matches, ctx)
    triggerGQCheckEnd("trg_gq_check_end", ctx.line, matches)
end, {name = "trg_gq_check_end", priority = 100})

rune.trigger.regex("^You are not currently on a campaign.", function(matches, ctx)
    rune.pane.clear("cpmobs")
end, {name = "trg_not_campaign", priority = 100})

rune.trigger.regex("CONGRATULATIONS! You have completed your campaign.", function(matches, ctx)
    triggerCampaignComplete("trg_cp_complete", ctx.line, matches)
end, {name = "trg_cp_complete", priority = 100})

rune.trigger.regex(".+ tells you 'I have selected \\d+ targets for you to hunt, \\w+\\.'", function(matches, ctx)
    triggerCampaignStart("trg_cp_started", ctx.line, matches)
end, {name = "trg_cp_started", priority = 100})

rune.trigger.regex("^You are \\w+ that .* through here, heading (\\w+)\\.$", function(matches, ctx)
    triggerHuntOutput("trg_hunt_output", ctx.line, matches)
end, {name = "trg_hunt_output", priority = 100})

rune.trigger.regex("^You are \\w+ that .* is (\\w+) from here\\.$", function(matches, ctx)
    triggerHuntOutput("trg_hunt_output_2", ctx.line, matches)
end, {name = "trg_hunt_output_2", priority = 100})

rune.trigger.regex("^You couldn't find a path to (.+)$", function(matches, ctx)
    autohuntCancel("trg_hunt_output_3", ctx.line, matches)
end, {name = "trg_hunt_output_3", priority = 100})

rune.trigger.regex("^No one in this area by the name", function(matches, ctx)
    autohuntCancel("trg_hunt_not_found", ctx.line, matches)
end, {name = "trg_hunt_not_found", priority = 100})

rune.trigger.regex(".+ is here!$", function(matches, ctx)
    autohuntCancel("trg_hunt_is_here", ctx.line, matches)
end, {name = "trg_hunt_is_here", priority = 100})

rune.trigger.regex("^You are confident that .* through here, heading (\\w+)\\.$", function(matches, ctx)
    hunttrickNext("trg_hunttrick_output", ctx.line, matches)
end, {name = "trg_hunttrick_output", priority = 100})

rune.trigger.regex("^You are \\w+ that .* is (\\w+) from here\\.$", function(matches, ctx)
    hunttrickNext("trg_hunttrick_output2", ctx.line, matches)
end, {name = "trg_hunttrick_output2", priority = 100})

rune.trigger.regex("^You couldn't find a path to (.+)$", function(matches, ctx)
    hunttrickNext("trg_hunttrick_output3", ctx.line, matches)
end, {name = "trg_hunttrick_output3", priority = 100})

rune.trigger.regex("^No one in this area by the name", function(matches, ctx)
    hunttrickCancel("trg_hunttrick_not_found", ctx.line, matches)
end, {name = "trg_hunttrick_not_found", priority = 100})

rune.trigger.regex(".+ is here!$", function(matches, ctx)
    hunttrickCancel("trg_hunttrick_is_here", ctx.line, matches)
end, {name = "trg_hunttrick_is_here", priority = 100})

rune.trigger.regex("^You seem unable to hunt that target for some reason\\.$", function(matches, ctx)
    hunttrickFound("trg_hunttrick_unable", ctx.line, matches)
end, {name = "trg_hunttrick_unable", priority = 100})

rune.trigger.regex("^You have now joined Global Quest # \\d+. See 'help gquest' for available commands\\.$", function(matches, ctx)
    triggerGQJoin("trg_gq_join", ctx.line, matches)
end, {name = "trg_gq_join", priority = 100})

rune.trigger.regex("^You have finished this global quest\\.$", function(matches, ctx)
    mobdbTriggerGQDone("trg_gq_end", ctx.line, matches)
end, {name = "trg_gq_end", priority = 100})

rune.trigger.regex("^Global Quest: Global quest # \\d+ has been cancelled due to lack of activity\\.$", function(matches, ctx)
    mobdbTriggerGQDone("trg_gq_inactivity_mobdb", ctx.line, matches)
end, {name = "trg_gq_inactivity_mobdb", priority = 100})

rune.trigger.regex("^You are not in a global quest\\.$", function(matches, ctx)
    mobdbTriggerGQDone("trg_gq_notin_mobdb", ctx.line, matches)
end, {name = "trg_gq_notin_mobdb", priority = 100})

rune.trigger.regex("^{scan}$", function(matches, ctx)
    triggerScanStart("trg_start_scan", ctx.line, matches)
end, {name = "trg_start_scan", priority = 10, gag = true})

rune.trigger.regex("^{/scan}$", function(matches, ctx)
    triggerScanEnd("trg_scan_end", ctx.line, matches)
end, {name = "trg_scan_end", priority = 10, gag = true})

rune.trigger.regex("^(.+) from here you see:$", function(matches, ctx)
    triggerScanDirection("trg_scan_direction", ctx.line, matches)
end, {name = "trg_scan_direction", priority = 100})

rune.trigger.regex("^(Right) here you see:$", function(matches, ctx)
    triggerScanDirection("trg_scan_right_here", ctx.line, matches)
end, {name = "trg_scan_right_here", priority = 100})

rune.trigger.regex("^\\s+- (.+)$", function(matches, ctx)
    triggerScanMob("trg_scan_mob", ctx.line, matches)
end, {name = "trg_scan_mob", priority = 10})

rune.trigger.regex("^(.+)$", function(matches, ctx)
    triggerConsiderLine("trg_consider_line", ctx.line, matches)
end, {name = "trg_consider_line", priority = 9})

rune.trigger.regex("^(.*?)\\s+(\\d+)\\s+\\d+\\s+\\d+\\s+\\w .*$", function(matches, ctx)
    triggerLastMob("trg_last_mob", ctx.line, matches)
end, {name = "trg_last_mob", priority = 10})

rune.trigger.regex("^(?:[^\\[\\]]|\\[[A-Za-z][^\\]]*\\])*$", function(matches, ctx)
    -- Returning data to the trigger will replace the line.
    return triggerMDBReplace("trg_mobdb_replace", ctx.line:clean(), matches)
end, {name = "trg_mobdb_replace", priority = 80, gag = false})

rune.trigger.regex("\\[\\d\\] (.+) is unaffected by your (.+)!", function(matches, ctx)
    updateMobImmunityFromCombat(matches[1],matches[2])
end)

-- Disable triggers that should be off by default
rune.trigger.disable("trg_gq_check_end")
rune.trigger.disable("trg_hunt_output")
rune.trigger.disable("trg_hunt_output_2")
rune.trigger.disable("trg_hunt_output_3")
rune.trigger.disable("trg_hunt_not_found")
rune.trigger.disable("trg_hunttrick_output")
rune.trigger.disable("trg_hunttrick_output2")
rune.trigger.disable("trg_hunttrick_output3")
rune.trigger.disable("trg_hunttrick_not_found")
rune.trigger.disable("trg_hunttrick_unable")
rune.trigger.disable("trg_scan_mob")
rune.trigger.disable("trg_consider_line")
rune.trigger.disable("trg_last_mob")
rune.trigger.disable("trg_mobdb_replace")


