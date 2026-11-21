rune.trigger.regex("^You entered: where (.+)", function(matches, ctx)
    return triggerStartWhere("trg_entered_where", ctx.line, matches)
end, {name = "trg_entered_where", priority = 100})

rune.trigger.regex("^You have now joined Global Quest # \\d+. See 'help gquest' for available commands\\.$", function(matches, ctx)
    return triggerGQJoin("trg_gq_join_mapper", ctx.line, matches)
end, {name = "trg_gq_join_mapper", priority = 100})

rune.trigger.regex("^You have finished this global quest\\.$", function(matches, ctx)
    return mapperTriggerGQDone("trg_gq_end_mapper", ctx.line, matches)
end, {name = "trg_gq_end_mapper", priority = 100})

rune.trigger.regex("^Global Quest: Global quest # \\d+ has been cancelled due to lack of activity\\.$", function(matches, ctx)
    return mapperTriggerGQDone("trg_gq_inactivity_mapper", ctx.line, matches)
end, {name = "trg_gq_inactivity_mapper", priority = 100})

rune.trigger.regex("^You are not in a global quest\\.$", function(matches, ctx)
    return mapperTriggerGQDone("trg_gq_notin", ctx.line, matches)
end, {name = "trg_gq_notin", priority = 100})

rune.trigger.regex("^You cannot return home from this room.$", function(matches, ctx)
    return setRoomNoRecall("trg_no_home", ctx.line, matches)
end, {name = "trg_no_home", priority = 100})

rune.trigger.regex("^Magic walls bounce you back.$", function(matches, ctx)
    return setRoomNoPortal("trg_no_portal", ctx.line, matches)
end, {name = "trg_no_portal", priority = 100})

rune.trigger.regex("^\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)?\\s+([[:alnum:]]+)\\s+(.+)", function(matches, ctx)
    return triggerAreasKeywords("trg_areas_keywords", ctx.line, matches)
end, {name = "trg_areas_keywords", priority = 100})

rune.trigger.disable("trg_areas_keywords")