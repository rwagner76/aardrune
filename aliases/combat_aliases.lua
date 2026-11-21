rune.alias.regex("^qa ?(.+)?$", function(matches, ctx)
    aliasQueueAttack("alias_queue_attack_noargs", ctx.line, matches)
end, {name = "alias_queue_attack_noargs", priority = 100})

rune.alias.regex("^ka$", function(matches, ctx)
    killAll("alias_kill_all", ctx.line, matches)
end, {name = "alias_kill_all", priority = 100})

rune.alias.regex("^(combat help|ch)$", function(matches, ctx)
    aliasCombatHelp("alias_combat_help", ctx.line, matches)
end, {name = "alias_combat_help", priority = 100})

rune.alias.regex("^(pa|preferredalign) (\\w+)$", function(matches, ctx)
    aliasPreferredAlign("alias_preferred_align", ctx.line, matches)
end, {name = "alias_preferred_align", priority = 100})

rune.alias.regex("^(kamax|killall max) (\\d+)$", function(matches, ctx)
    setKillAllMax("alias_killall_max", ctx.line, matches)
end, {name = "alias_killall_max", priority = 100})

rune.alias.regex("^(kamin|killall min) (\\d+)$", function(matches, ctx)
    setKillAllMin("alias_killall_min", ctx.line, matches)
end, {name = "alias_killall_min", priority = 100})

rune.alias.regex("^cq$", function(matches, ctx)
    clearKillAllQueue("alias_clear_killall_queue", ctx.line, matches)
end, {name = "alias_clear_killall_queue", priority = 100})

rune.alias.regex("^(as|attackskill) (.+)$", function(matches, ctx)
    setAttackSkill("alias_set_attackskill", ctx.line, matches)
end, {name = "alias_set_attackskill", priority = 100})

rune.alias.regex("^as$", function(matches, ctx)
    doAttackSkill("alias_do_attackskill", ctx.line, matches)
end, {name = "alias_do_attackskill", priority = 100})

rune.alias.regex("^killcommand (.+)$", function(matches, ctx)
    setKillCommand("alias_set_kill_command", ctx.line, matches)
end, {name = "alias_set_kill_command", priority = 100})

rune.alias.regex("^look$", function(matches, ctx)
    aliasLook("alias_look", ctx.line, matches)
end, {name = "alias_look", priority = 100})

rune.alias.regex("^cs$", function(matches, ctx)
    aliasCombatStab("alias_combat_stab", ctx.line, matches)
end, {name = "alias_combat_stab", priority = 100})

rune.alias.regex("^(?:mr|midround)(?:\\s(\\w+))?$", function(matches, ctx)
    aliasMidround(ctx.matches)
end, {name = "alias_midround", priority = 100})