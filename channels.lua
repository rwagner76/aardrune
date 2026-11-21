rune.gmcp.subscribe("comm")

rune.gmcp.on("comm.channel", function(data)
	chan,msg,player = data.chan,data.msg,data.player
    local filterchannels = {"ftalk","clantalk","newbie","answer","question","gtell","helper"}
    if table.contains(filterchannels,chan) then rune.pane.write("chat",msg) end
end)

rune.pane.create("chat")

rune.alias.exact("tchat", function()
   layout.setPane("middle", "chat")
end)


