rune.alias.regex("^showtriggers$", function(matches, ctx)
    showTriggers()    
end, {name = "alias_showtriggers"})

rune.alias.regex("^showaliases$", function(matches, ctx)
    showAliases()
end, {name = "alias_showaliases"})


