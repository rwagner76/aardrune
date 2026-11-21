rune.alias.regex("^bpm$", function(matches, ctx)
    aliasBpmList("alias_bpm_list", ctx.line, matches)
end, {name = "alias_bpm_list", priority = 100})

rune.alias.regex("^bpm update$", function(matches, ctx)
    aliasBpmUpdate("alias_bpm_update", ctx.line, matches)
end, {name = "alias_bpm_update", priority = 99})

rune.alias.regex("^bpm clear$", function(matches, ctx)
    aliasBpmClear("alias_bpm_clear", ctx.line, matches)
end, {name = "alias_bpm_clear", priority = 99})

rune.alias.regex("^bpm help$", function(matches, ctx)
    aliasBpmHelp("alias_bpm_help", ctx.line, matches)
end, {name = "alias_bpm_help", priority = 99})

rune.alias.regex("^bpm (.+)$", function(matches, ctx)
    aliasBpmToggle("alias_bpm_toggle", ctx.line, matches)
end, {name = "alias_bpm_toggle", priority = 100})

rune.alias.regex("^bpmp (.+) (\\d+)$", function(matches, ctx)
    aliasBpmSetPriority("alias_bpmp_set", ctx.line, matches)
end, {name = "alias_bpmp_set", priority = 100})
