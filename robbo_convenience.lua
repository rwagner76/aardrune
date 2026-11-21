-- Triggers
rune.trigger.exact("Darkon Stills drops a blessed cross.", function(name, line, wildcards)
    rune.send_raw("get cross")
    rune.send_raw("keep cross")
    rune.send_raw("put cross pots")
end, {name = "trg_blessed_cross"})

-- Aliases
rune.alias.exact("ahpet", function()
    rune.send("ah ducksucker")
end)

rune.alias.exact("annwn", function()   
    rune.send("pendwalk 28966 give 6000 coins inkeeper")
    rune.send("mapper goto 28966")
end)

rune.alias.exact("astral", function()
    rune.send("mapper goto 27911")
    rune.send("echo Note: Get sand, go to insomniac, give sand insomniac")
end)

rune.alias.exact("bonds", function()
    rune.send("mapper goto 23435")
end)

rune.alias.exact("coug", function()   
    rune.send("pendwalk 14314 enter opening;;ah guard")
    rune.send("pendwalk 14321 roar")
    rune.send("mapper goto 14314")
end)

rune.alias.exact("damned", function()   
    rune.send("pendwalk 10469 take cross0904 pots;;unkeep cross0904;;give cross0904 darkon;;keep star")
    rune.send("mapper goto 10469")
end)

rune.alias.exact("deskey", function()
    rune.send("pendwalk 47533 take all desk")
    rune.send("mapper goto 47533")
end)

rune.alias.exact("dunoir", function()   
    rune.send("mapper goto 14293")
end)

rune.alias.exact("empy", function()   
    rune.send("mapper goto 13946")
end)

rune.alias.exact("ftjack", function()   
    rune.send("pendwalk 26765 *pat cow;;s;;say yes;;run wu")
    rune.send("mapper goto 26765")
end)

rune.alias.exact("gallows", function()
    rune.send("mapper goto 4384")
end)

rune.alias.exact("gauntlet", function()
    rune.send("pendwalk 31675 w")
    rune.send("mapper goto 31675")
end)

rune.alias.exact("goldrush", function()
    rune.send("pendwalk 15044 ah wight")
    rune.send("pendwalk 15048 enter crack")
    rune.send("mapper goto 15044")
end)

rune.alias.exact("helegear", function()   
    rune.send("pendwalk 30701 ah eternal")
    rune.send("mapper goto 30701")
end)

rune.alias.exact("hom", function()
    rune.send("mapper goto 44714")
end)

rune.alias.exact("imagi", function()
    rune.send("mapper goto 36808")
end)

rune.alias.exact("kiddie", function()
    rune.send("pendwalk 36704 say kiddie")
    rune.send("mapper goto 36704")
end)

rune.alias.exact("knoss", function()   
    addPendingSpeedwalk(nil,nil,{"28193","run nes;buy steak;run n2wn;buy silv;run 2swn;enter shack;give steak hobo;run esen2en2w;enter crack;give silver sayra;run 2e4nwn;give id gua;give pass gua"})
    --rune.send("pendwalk 28193 run nes;;buy steak;;run n2wn;;buy silv;;run 2swn;;enter shack;;give steak hobo;;run esen2en2w;;enter crack;;give silver sayra;;run 2e4nwn;;give id gua;;give pass gua")
    rune.send("mapper goto 28193")
end)

rune.alias.exact("maelstrom", function()
    rune.send("mapper goto 38071")
end)

rune.alias.exact("minos", function()
    rune.send("mapper goto 20566")
end)

rune.alias.exact("moricand", function()
    rune.send("mapper goto 26969")
end)

rune.alias.exact("nix", function()   
    rune.send("pendwalk 10305 run 2s;;say nechtan;;say blessing;;wear blessing;;wear balance")
    rune.send("mapper goto 10305")
end)

rune.alias.exact("nottingham", function()   
    rune.send("pendwalk 11077 ah shakey")
    rune.send("mapper goto 11077")
end)

rune.alias.exact("nsevil", function()
    rune.send("mapper goto 11201")
end)

rune.alias.exact("nsgood", function()
    rune.send("mapper goto 11168")
end)

rune.alias.exact("nyne", function()
    rune.send("mapper goto 23576")
end)

rune.alias.exact("pompeii", function()   
    rune.send("pendwalk 42 open table;;get scroll table;;open n;;n")
    rune.send("mapper goto 42")
end)

rune.alias.exact("pool", function(args,ctx)
   if args == "" then
      rune.echo("Usage: pool <pool number>")
      rune.echo("Note: Don't forget to bring a pet!")
   else
       rune.send("transport 1115592")
       rune.send_raw("run "..args.."e")
       rune.send_raw("enter pool")
       rune.send_raw("heel")
       rune.send_raw("order ducksucker sleep")
   end
end)

rune.alias.exact("rock", function()   
    rune.send("pendwalk 472 say gardens")
    rune.send("mapper goto 472")
end)

rune.alias.exact("rubber", function()   
    rune.send("pendwalk 427 d")
    rune.send("mapper goto 427")
end)

rune.alias.exact("ruins1", function()
    rune.send("mapper goto 16805")
end)

rune.alias.exact("scarred", function()   
    rune.send("pendwalk 34037 ah undead miner")
    rune.send("mapper goto 34037")
end)

rune.alias.exact("seawitch", function()
    rune.send("mapper goto 28269")
end)

rune.alias.exact("silver", function()
    rune.send("pendwalk 6134 echo Key is on the Balrog's Adept")
    rune.send("mapper goto 6134")
end)

rune.alias.exact("skullgore", function()
    rune.send("mapper goto 19648")
end)

rune.alias.exact("stone", function()
    rune.send("mapper goto 11400")
end)

rune.alias.exact("sunrise", function()
    rune.send("mapper goto 4196")
end)

rune.alias.exact("sunset", function()
    rune.send("mapper goto 4217")
end)

rune.alias.exact("tirna", function()
    rune.send("pendwalk 20147 run ne")
    rune.send("mapper goto 20147")
end)

rune.alias.exact("umari", function()
    rune.send("pendwalk 36645 say umari")
    rune.send("mapper goto 36645")
end)

rune.alias.exact("vidblain", function()
    rune.send("pendwalk 11910 enter hole")
    rune.send("mapper goto 11910")
end)

rune.alias.exact("vlad", function()
    rune.send("pendwalk 15970 ah castle patrol guard")
    rune.send("mapper goto 15970")
end)

rune.alias.exact("yarr", function()
    rune.send("mapper goto 30317")
end)

