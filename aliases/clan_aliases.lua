rune.alias.regex("^updateroster$", function(matches, ctx)
    updateClanRoster("alias_updateroster", ctx.line, ctx.args)
end, {name = "alias_updateroster", priority = 100})

rune.alias.regex("^In a grand military parade, (\\w+) marches off to \\w+ next posting.$", function(matches, ctx)
    triggerClanOutcast("alias_clan_outcast", ctx.line, ctx.args)
end, {name = "alias_clan_outcast", priority = 100})