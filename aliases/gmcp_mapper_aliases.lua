rune.alias.regex("^mapper save$", function(matches, ctx)
    saveMapperData("alias_mapper_save", ctx.line, matches)
end, {name = "alias_mapper_save", priority = 100})

rune.alias.regex("^mapper profile ?(.*)?$", function(matches, ctx)
    aliasMapperProfile("alias_mapper_profile", ctx.line, matches)
end, {name = "alias_mapper_profile", priority = 100})

rune.alias.regex("^mapper gqstate$", function(matches, ctx)
    aliasMapperGQState("alias_mapper_gqstate", ctx.line, matches)
end, {name = "alias_mapper_gqstate", priority = 100})

rune.alias.regex("^(mapper find|rfind|rf) (.+)$", function(matches, ctx)
    aliasMapperFindRoom("alias_mapper_find", ctx.line, matches)
end, {name = "alias_mapper_find", priority = 100})

rune.alias.regex("^pendwalk (\\d+) (.+)$", function(matches, ctx)
    addPendingSpeedwalk("alias_mapper_pendwalk", ctx.line, matches)
end, {name = "alias_mapper_pendwalk", priority = 100})

rune.alias.regex("^mapper _directive_notice (\\d+)$", function(matches, ctx)
    aliasMapperDirectiveNotice("alias_mapper_directive_notice", ctx.line, matches)
end, {name = "alias_mapper_directive_notice", priority = 100})

rune.alias.regex("^mapper help ?(.+)?$", function(matches, ctx)
    aliasMapperHelp("alias_mapper_help", ctx.line, matches)
end, {name = "alias_mapper_help", priority = 100})

rune.alias.regex("^mapper help (exits|portals|exit|portal)$", function(matches, ctx)
    aliasMapperHelpExits("alias_mapper_help_exits", ctx.line, matches)
end, {name = "alias_mapper_help_exits", priority = 99})

rune.alias.regex("^(mapper roominfo|mapper thisroom|ri) (.+)?$", function(matches, ctx)
    aliasMapperRoomInfo("alias_mapper_room_info_arg", ctx.line, matches)
end, {name = "alias_mapper_room_info_arg", priority = 100})

rune.alias.regex("^(mapper roominfo|mapper thisroom|ri)$", function(matches, ctx)
    aliasMapperRoomInfo("alias_mapper_room_info", ctx.line, matches)
end, {name = "alias_mapper_room_info", priority = 100})

rune.alias.regex("^mapper room (\\d+) delete$", function(matches, ctx)
    aliasMapperRoomDelete("alias_mapper_room_delete", ctx.line, matches)
end, {name = "alias_mapper_room_delete", priority = 100})

rune.alias.regex("^mapper rooms$", function(matches, ctx)
    aliasMapperZoneRooms("alias_mapper_zone_rooms", ctx.line, matches)
end, {name = "alias_mapper_zone_rooms", priority = 100})

rune.alias.regex("^(mapper exitinfo|mapper portalinfo|ei|pi) (.+)?$", function(matches, ctx)
    aliasMapperExitInfo("alias_mapper_exit_info_arg", ctx.line, matches)
end, {name = "alias_mapper_exit_info_arg", priority = 100})

rune.alias.regex("^(mapper exitinfo|mapper portalinfo|ei|pi)$", function(matches, ctx)
    aliasMapperExitInfo("alias_mapper_exit_info", ctx.line, matches)
end, {name = "alias_mapper_exit_info", priority = 100})

rune.alias.regex("^mapper findpath (\\d+) (\\d+)$", function(matches, ctx)
    aliasFindPath("alias_mapper_findpath", ctx.line, matches)
end, {name = "alias_mapper_findpath", priority = 100})

rune.alias.regex("^(mapper goto|sw) (.+)$", function(matches, ctx)
    aliasMapperGoto("alias_mapper_goto", ctx.line, matches)
end, {name = "alias_mapper_goto", priority = 100})

rune.alias.regex("^mapper area goto (.+)$", function(matches, ctx)
    aliasMapperAreaGoto("alias_mapper_area_goto", ctx.line, matches)
end, {name = "alias_mapper_area_goto", priority = 100})

rune.alias.regex("^mapper areas ?(.+)?$", function(matches, ctx)
    aliasMapperAreas("alias_mapper_areas", ctx.line, matches)
end, {name = "alias_mapper_areas", priority = 100})

rune.alias.regex("^mapper update area ([[:alnum:]]+) (\\w+) (.+)$", function(matches, ctx)
    aliasAreaUpdate("alias_mapper_update_area", ctx.line, matches)
end, {name = "alias_mapper_update_area", priority = 100})

rune.alias.regex("^mapper exits$", function(matches, ctx)
    mapperDisplayExits("alias_mapper_exits", ctx.line, matches)
end, {name = "alias_mapper_exits", priority = 100})

rune.alias.regex("^mapper portals$", function(matches, ctx)
    mapperDisplayPortals("alias_mapper_portals", ctx.line, matches)
end, {name = "alias_mapper_portals", priority = 100})

rune.alias.regex("^arun (.+)$", function(matches, ctx)
    aliasMapperAreaGoto("alias_arun", ctx.line, matches)
end, {name = "alias_arun", priority = 100})

rune.alias.regex("^go(w(h(e(r(e)?)?)?)?)?$", function(matches, ctx)
    aliasGoWhere("alias_gowhere", ctx.line, matches)
end, {name = "alias_gowhere", priority = 100})

rune.alias.regex("^mapper (exit|portal) (\\d+) (\\w+) ?(.+)?$", function(matches, ctx)
    aliasMapperExit("alias_mapper_exit", ctx.line, matches)
end, {name = "alias_mapper_exit", priority = 100})

rune.alias.regex("^mapper (exit|portal) search (.+)$", function(matches, ctx)
    aliasExitSearch("alias_exit_search", ctx.line, matches)
end, {name = "alias_exit_search", priority = 100})

rune.alias.regex("^roomnote (.+)$", function(matches, ctx)
    aliasRoomNote("alias_room_note", ctx.line, matches)
end, {name = "alias_room_note", priority = 100})

rune.alias.regex("^areanote (.+)$", function(matches, ctx)
    aliasAreaNote("alias_area_note", ctx.line, matches)
end, {name = "alias_area_note", priority = 100})

rune.alias.regex("^mapper cexit (.+)$", function(matches, ctx)
    aliasMapperCExit("alias_mapper_cexit", ctx.line, matches)
end, {name = "alias_mapper_cexit", priority = 100})

rune.alias.regex("^mapper createportal (.+)$", function(matches, ctx)
    aliasMapperCExit("alias_mapper_createportal", ctx.line, matches)
end, {name = "alias_mapper_createportal", priority = 100})

rune.alias.regex("^mapper createexit (\\d+) (\\d+) (.+)$", function(matches, ctx)
    aliasMapperCreateExit("alias_mapper_createexit_full", ctx.line, matches)
end, {name = "alias_mapper_createexit_full", priority = 100})

rune.alias.regex("^mapper createexit (\\d+) (.+)$", function(matches, ctx)
    aliasMapperCreateExit("alias_mapper_createexit_default", ctx.line, matches)
end, {name = "alias_mapper_createexit_default", priority = 100})

rune.alias.regex("^(mapper refreshareas|updateareas)$", function(matches, ctx)
    aliasMapperRefreshAreas("alias_mapper_refresh_areas", ctx.line, matches)
end, {name = "alias_mapper_refresh_areas", priority = 100})

rune.alias.regex("^sethome (\\d+)$",function(matches,ctx)
    aliasSetHome("alias_sethome", ctx.line, matches)
end)