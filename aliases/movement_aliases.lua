rune.alias.regex("^(?:graveyard|gy) (.+)$", function(matches, ctx)
    aliasGraveYard("alias_graveyard", ctx.line, matches)
end, {name = "alias_graveyard", priority = 100})

rune.alias.exact("getpet", function()
   rune.send("pendwalk 32587 adopt crawler ducksucker")
   rune.send("mapper goto 32587")
end)

rune.alias.exact("opa", "op n;op s;op e;op w;op u;op d")