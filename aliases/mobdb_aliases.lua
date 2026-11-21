rune.alias.regex("^mobdb save$", function(matches, ctx)
    saveMobDBToDisk()
end, {name = "alias_mobdb_save"})

rune.alias.regex("^(mobdb find|mf) (.+)$", function(matches, ctx)
    aliasMobdbFind("alias_mobdb_find", ctx.line, matches)
end, {name = "alias_mobdb_find"})

rune.alias.regex("^(mobdb info|mi) (\\d+)$", function(matches, ctx)
    mobdbInfo("alias_mobdb_info", ctx.line, matches)
end, {name = "alias_mobdb_info"})

rune.alias.regex("^(mobdb add|ma) manual (.+)$", function(matches, ctx)
    mobdbAddManual("alias_mobdb_add_manual", ctx.line, matches)
end, {name = "alias_mobdb_add_manual"})

rune.alias.regex("^(mobdb add|ma) (.+)$", function(matches, ctx)
    mobdbAdd("alias_mobdb_add", ctx.line, matches)
end, {name = "alias_mobdb_add"})

rune.alias.regex("^(mobdb add|ma)$", function(matches, ctx)
    mobdbAdd("alias_mobdb_add_noargs", ctx.line, matches)
end, {name = "alias_mobdb_add_noargs"})

rune.alias.regex("^mobdb delete (.+)$", function(matches, ctx)
    mobdbDelete("alias_mobdb_delete", ctx.line, matches)
end, {name = "alias_mobdb_delete"})

rune.alias.regex("^mobdb help$", function(matches, ctx)
    aliasMobdbHelp("alias_mobdb_help", ctx.line, matches)
end, {name = "alias_mobdb_help"})

rune.alias.regex("^(\\d)$", function(matches, ctx)
    mobdbAddSelect("alias_mobadd_select", ctx.line, matches)
end, {name = "alias_mobadd_select"})

rune.alias.disable("alias_mobadd_select")

rune.alias.regex("^(mobdb update|mu) (\\d+) (\\w+) (.+)$", function(matches, ctx)
    mobdbUpdate("alias_mobdb_update", ctx.line, matches)
end, {name = "alias_mobdb_update"})

rune.alias.regex("^(mobwhere|mw) (.+)$", function(matches, ctx)
    aliasMobWhere("alias_mobwhere", ctx.line, matches)
end, {name = "alias_mobwhere"})

rune.alias.regex("^scan$", function(matches, ctx)
    aliasSmartScan("alias_smart_scan", ctx.line, matches)
end, {name = "alias_smart_scan"})

rune.alias.regex("^scan (.+)$", function(matches, ctx)
    aliasSmartScan("alias_smart_scan_args", ctx.line, matches)
end, {name = "alias_smart_scan_args"})

rune.alias.regex("^cp c(h(e(c(k)?)?)?)?$", function(matches, ctx)
   aliasCampaignCheck("alias_campaign_check", ctx.line, matches)
end, {name = "alias_campaign_check"})

rune.alias.regex("^gq c(h(e(c(k)?)?)?)?$", function(matches, ctx)
    aliasGQCheck("alias_gq_check", ctx.line, matches)
end, {name = "alias_gq_check"})

rune.alias.regex("^ah (.+)$", function(matches, ctx)
    autohuntEnable("alias_auto_hunt_enable", ctx.line, matches)
end, {name = "alias_auto_hunt_enable"})

rune.alias.regex("^ht (.+)$", function(matches, ctx)
    aliasHuntTrick("alias_hunt_trick", ctx.line, matches)
end, {name = "alias_hunt_trick"})

rune.alias.regex("^cons$", function(matches, ctx)
    aliasConsiderTrack("alias_consider_track_noargs", ctx.line, matches)
end, {name = "alias_consider_track_noargs"})

rune.alias.regex("^cons (.+)$", function(matches, ctx)
    aliasConsiderTrack("alias_consider_track", ctx.line, matches)
end, {name = "alias_consider_track"})

rune.alias.regex("^planes ?(.*)$", function(matches, ctx)
    aliasPlanesSearch("alias_planes_search", ctx.line, matches)
end, {name = "alias_planes_search"})

rune.alias.regex("^cg(r|a|l)? ?(\\d+)?$", function(matches, ctx)
    campaignGo("alias_campaign_go", ctx.line, matches)
end, {name = "alias_campaign_go"})

rune.alias.regex("^gg(r|a|l)? ?(\\d+)?$", function(matches, ctx)
    gquestGo("alias_gquest_go", ctx.line, matches)
end, {name = "alias_gquest_go"})

rune.alias.regex("^cgh$", function(matches, ctx)
    aliascpgqht("alias_campaign_hunttrick", ctx.line, matches)
end, {name = "alias_campaign_hunttrick"})

rune.alias.regex("^ggh$", function(matches, ctx)
    aliascpgqht("alias_gquest_hunttrick", ctx.line, matches)
end, {name = "alias_gquest_hunttrick"})
