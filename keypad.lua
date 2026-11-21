local kpmode = "campaign"

rune.config.set("numpad",true)

rune.bind("numpad8",function() rune.send("n") end)
rune.bind("numpad2",function() rune.send("s") end)
rune.bind("numpad6",function() rune.send("e") end)
rune.bind("numpad4",function() rune.send("w") end)
rune.bind("numpad9",function() rune.send("u") end)
rune.bind("numpad3",function() rune.send("d") end)
rune.bind("numpad1",function() rune.send("as") end)
rune.bind("numpad7",function() rune.send("qa") end)
rune.bind("numpad0",function() rune.send("cg") end)
rune.bind("numpad_dot",function() rune.send("cp check") end)
rune.bind("numpad_plus",function() rune.send("spellup") end)
rune.bind("numpad_slash",function() rune.send("qheal") end)
rune.bind("numpad_star",function() rune.send("qmana") end)
