rune.alias.exact("slist", function(ctx)
    aliasSlist("alias_slist", ctx.line, matches)
end, {priority = 100})

rune.alias.exact("spellup", function(ctx)
    aliasSpellup("alias_spellup", ctx.line, matches)
end, {priority = 100})

rune.alias.exact("cureall", function(ctx)
    aliasCureAll("alias_cureall", ctx.line, matches)
end, {priority = 100})

rune.alias.exact("dumpsaff", function(ctx)
    aliasDumpSaff("alias_dump_saff", ctx.line, matches)
end, {priority = 100})
