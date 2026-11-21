rune.alias.regex("^qr$", function(matches, ctx)
    aliasQuest("alias_questrequest", ctx.line, matches)
end, {name = "alias_questrequest", priority = 100})

rune.alias.regex("^qi$", function(matches, ctx)
    aliasQuest("alias_questinfo", ctx.line, matches)
end, {name = "alias_questinfo", priority = 100})

rune.alias.regex("^qc$", function(matches, ctx)
    aliasQuest("alias_questcomplete", ctx.line, matches)
end, {name = "alias_questcomplete", priority = 100})

rune.alias.regex("^autonoexp (\\d+)$", function(matches, ctx)
    aliasAutoNoExp("alias_auto_noexp", ctx.line, matches)
end, {name = "alias_auto_noexp", priority = 100})

rune.alias.regex("^debugcp$", function(matches, ctx)
    dumpCPState("alias_debug_cp", ctx.line, matches)
end, {name = "alias_debug_cp", priority = 100})