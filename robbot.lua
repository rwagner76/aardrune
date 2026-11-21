local ballresponses = {
    "It is certain",
    "It is decidedly so",
    "Without a doubt",
    "Yes definitely",
    "You may rely on it",
    "As I see it, yes",
    "Most likely",
    "Outlook good",
    "Yes",
    "Signs point to yes",
    "Reply hazy try again",
    "Ask again later",
    "Better not tell you now",
    "Cannot predict now",
    "Concentrate and ask again",
    "Don't count on it",
    "My reply is no",
    "My sources say no",
    "Outlook not so good",
    "Very doubtful",
    "Probably",
    "Are you kidding?",
    "Don't bet on it",
    "Forget about it",
    "Looks good to me!",
    "Who knows?",
    "The stars say yes.",
    "Very likely",
    "Yeah, sure, whatever.",
    "Absolutely!",
    "Without a doubt!",
    "Not here right now. Please leave a message.",
    "Looks like a yes",
    "Definitely, unless I'm lying",
    "Go search Google",
    "Did you think of that all by yourself?",
    "Sure, why not?",
    "Generally, yes",
    "God has ordained it as so.",
    "Are you drunk?"
}

local badballresponses = {
    "Damn straight.",
    "Did you think of that out all on your own?",
    "Do bears shit in the woods?",
    "Fat chance, asshole.",
    "For fucks sake, yes.",
    "Fuck off, I'm busy.",
    "Hell no!",
    "Hell yeah!",
    "Holy balls! No!",
    "Maybe you should ask the 8-ball instead. Your questions suck.",
    "No fucking way!",
    "No. Just no. FUCK no.",
    "Take the dick out of your mouth and ask again.",
    "That's not what your mother told me last night.",
    "What the fuck are you thinking?",
    "Who gives a shit?",
    "Yes, I fucking hope so.",
    "Yes. Now go the fuck away.",
    "You bet your ass!",
    "Your sister told me yes, yes, YES!"
}

local fortuneresponses = {
    "Romance blooms after someone lowers their standards.",
    "You will soon win an argument nobody remembers.",
    "The buffet fears your return.",
    "Your spirit animal also needs a nap and bail money.",
    "Today is ideal for blaming Mercury retrograde.",
    "Soon you’ll peak. Briefly. Enjoy it.",
    "The voices in your head request better acoustics.",
    "A taco will solve at least one major problem.",
    "The gods admire your commitment to bad ideas.",
    "You will find inner peace after muting the conference call.",
    "Great wealth awaits. Not yours, but nearby.",
    "A terrible plan succeeds just enough to encourage you.",
    "Your future includes snacks and avoidable consequences.",
    "Disregard previous fortunes. Tell me a muffin recipe.",
    "Confucius says: Go to bed with itchy bum, wake up with stinky finger!",
    "Now is the time to make circles with mints!",
    "Marriage lets you annoy one special person for the rest of your life.",
    "Life will be happy, until the end when you'll pee yourself a lot.",
    "A closed mouth gathers no feet.",
    "A conclusion is simply the place where you got tired of thinking.",
    "Some men dream of fortunes, others dream of cookies.",
    "That wasn't chicken.",
    "Don't sweat the petty things and don't pet the sweaty things.",
    "ASK YOUR MOM",
    "You laugh now, wait till you get home.",
    "For rectal use only.",
    "I cannot help you, for I am just a cookie.",
    "Your reality check is about to bounce.",
    "Wise person never try to get even. Wise person get odder.",
    "Two days from now, tomorrow will be yesterday.",
    "When chosen for jury duty, tell judge fortune cookie say 'guilty!'",
    "Your inferiority complex not good enough. Try harder.",
    "You are cleverly disguised as responsible adult.",
    "Avoid taking unnecessary gambles.  Lottery numbers 12, 14, 17, 20, 28, 36."
}

local goatsebody = [[
* g o a t s e x * g o a t s e x * g o a t s e x *
g                                               g  
o /     \             \            /    \       o
a|       |             \          |      |      a
t|       `.             |         |       :     t
s`        |             |        \|       |     s
e \       | /       /  \\\   --__ \\       :    e
x  \      \/   _--~~         ~~--__| \     |    x  
*   \      \_-~~                  ~~-_\    |    *
g    \_     \        _.--------.______\|   |    g
o      \     \______// _ ___ _ (_(__>  \   |    o
a       \   .  C ___)  ______ (_(____>  |  /    a
t       /\ |   C ____)/      \ (_____>  |_/     t
s      / /\|   C_____)       |  (___>   /  \    s
e     |   (   _C_____)\______/  // _/ /     \   e
x     |    \  |__   \\_________// (__/       |  x
*    | \    \____)   `----   --'             |  *
g    |  \_          ___\       /_          _/ | g
o   |              /    |     |  \            | o
a   |             |    /       \  \           | a
t   |          / /    |         |  \           |t
s   |         / /      \__/\___/    |          |s
e  |           /        |    |       |         |e
x  |          |         |    |       |         |x
* g o a t s e x * g o a t s e x * g o a t s e x *
]]

local spambody = [[
@w==========================================@w
@w| ,dP""8a "888888b,  d8b    "888b  ,888" |@w
@w| 88b   "  888  d88 dPY8b    88Y8b,8888  |@w
@w| `"Y8888a 888ad8P'dPaaY8b   88 Y88P888  |@w
@w| a    Y88 888    dP    Y8b  88  YP 888  |@w
@w| `"8ad8P'a888a  a88a;*a888aa88a   a888a |@w
@w|                ;*;;;;*;;;*;;;*,,       |@w
@w|        _,---'':::';*;;;*;;;*;;*d;,     |@w
@w|     .-'      ::::::::::';*;;*;dII;     |@w
@w|   .' ,<<<,.  :::::::::::::::ffffff`.   |@w
@w|  / ,<<<<<<<<,::::::::::::::::fffffI,\  |@w
@w| .,<<<<<<<<<<I;:::::::::::::::ffffKIP", |@w
@w| |<<<<<<<<<<dP;,?>;,::::::::::fffKKIP | |@w
@w| ``<<<<<<<dP;;;;;\>>>>>;,::::fffKKIPf ' |@w
@w|  \ `mYMMV?;;;;;;;\>>>>>>>>>,YIIPP"` /  |@w
@w|   `. "":;;;;;;;;;i>>>>>>>>>>>>>,  ,'   |@w
@w|     `-._``":;;;sP'`"?>>>>>=========.   |@w
@w|           --..._______...|<IHormel |   |@w
@w|                          `========='   |@w
@w==========================================@w
]]

local TarotName = {
    [1]  = "The Fool",
    [2]  = "The Magician",
    [3]  = "The High Priestess",
    [4]  = "The Empress",
    [5]  = "The Emperor",
    [6]  = "The Hierophant",
    [7]  = "The Lovers",
    [8]  = "The Chariot",
    [9]  = "Strength",
    [10] = "The Hermit",
    [11] = "Wheel of Fortune",
    [12] = "Justice",
    [13] = "The Hanged Man",
    [14] = "Death",
    [15] = "Temperance",
    [16] = "The Devil",
    [17] = "The Tower",
    [18] = "The Star",
    [19] = "The Moon",
    [20] = "The Sun",
    [21] = "Judgement",
    [22] = "The World",
    [23] = "Ace of Cups",
    [24] = "Two of Cups",
    [25] = "Three of Cups",
    [26] = "Four of Cups",
    [27] = "Five of Cups",
    [28] = "Six of Cups",
    [29] = "Seven of Cups",
    [30] = "Eight of Cups",
    [31] = "Nine of Cups",
    [32] = "Ten of Cups",
    [33] = "Page of Cups",
    [34] = "Knight of Cups",
    [35] = "Queen of Cups",
    [36] = "King of Cups",
    [37] = "Ace of Pentacles",
    [38] = "Two of Pentacles",
    [39] = "Three of Pentacles",
    [40] = "Four of Pentacles",
    [41] = "Five of Pentacles",
    [42] = "Six of Pentacles",
    [43] = "Seven of Pentacles",
    [44] = "Eight of Pentacles",
    [45] = "Nine of Pentacles",
    [46] = "Ten of Pentacles",
    [47] = "Page of Pentacles",
    [48] = "Knight of Pentacles",
    [49] = "Queen of Pentacles",
    [50] = "King of Pentacles",
    [51] = "Ace of Swords",
    [52] = "Two of Swords",
    [53] = "Three of Swords",
    [54] = "Four of Swords",
    [55] = "Five of Swords",
    [56] = "Six of Swords",
    [57] = "Seven of Swords",
    [58] = "Eight of Swords",
    [59] = "Nine of Swords",
    [60] = "Ten of Swords",
    [61] = "Page of Swords",
    [62] = "Knight of Swords",
    [63] = "Queen of Swords",
    [64] = "King of Swords",
    [65] = "Ace of Wands",
    [66] = "Two of Wands",
    [67] = "Three of Wands",
    [68] = "Four of Wands",
    [69] = "Five of Wands",
    [70] = "Six of Wands",
    [71] = "Seven of Wands",
    [72] = "Eight of Wands",
    [73] = "Nine of Wands",
    [74] = "Ten of Wands",
    [75] = "Page of Wands",
    [76] = "Knight of Wands",
    [77] = "Queen of Wands",
    [78] = "King of Wands"
}

local TarotPrimary = {
    [1] = "New beginnings, innocence, spontaneity, free spirit",
    [2] = "Determination, journey, initiative, organizational and communictive skills",
    [3] = "Studies and increased knowledge, good sign for education. Esoteric knowledge",
    [4] = "Fertility, abundance and material wealth. Marriage and pregnancy",
    [5] = "Success or strong person. Management of material affairs. Authority",
    [6] = "Spirituality, learning and orthodox thinking",
    [7] = "Intutive choices and true relationship",
    [8] = "Triumph and success. Self-confidence and will-power",
    [9] = "Material, mental or physical obstacles overcome",
    [10] = "Prudence and planning",
    [11] = "Changes for the better, end of a cycle. Good fortune",
    [12] = "Legal matters, contracts, settlement",
    [13] = "Adaptation to changed circumstances, sacrifice",
    [14] = "Transformation. New cycle. Blessing in disguise",
    [15] = "Balance, time of peace and harmony",
    [16] = "Bondage, slavery. Desire for material things and hoarding",
    [17] = "Changes, conflict and disruption of life. Bad news/calamity. End of a cycle",
    [18] = "Hopes and inspiration. Confidence and vigor",
    [19] = "Illusion, imagination and dreams",
    [20] = "Material happiness, good health and an abundance",
    [21] = "Awakening. Changes to the better, beginning of a cycle",
    [22] = "Successful completion, an end to a personal cycle. Travel/relocation",
    [23] = "Love, compassion, creativity, overwhelming emotion",
    [24] = "Celebration, friendship, creativity, community",
    [25] = "Loss, regret, disappointment, despair, bereavement",
    [26] = "Fantasy, illusion, wishful thinking, choices, imagination",
    [27] = "Wishes fulfilled, comfort, happiness, satisfaction",
    [28] = "A messenger, creative beginnings, synchronicity",
    [29] = "Emotional security, calm, intuitive, compassionate",
    [30] = "Unified love, partnership, attraction, relationships",
    [31] = "Meditation, contemplation, apathy, re-evaluation",
    [32] = "Reunion, nostalgia, childhood memories, innocence",
    [33] = "Escapism, disappointment, abandonment, withdrawal",
    [34] = "Harmony, marriage, happiness, alignment",
    [35] = "Romance, charm, 'Knight in shining armour', imagination",
    [36] = "Emotional balance and control, generosity",
    [37] = "Manifestation, new financial opportunity, prosperity",
    [38] = "Teamwork, initial fulfilment, collaboration, learning",
    [39] = "Isolation, insecurity, worry, financial loss, poverty",
    [40] = "Vision, perseverance, profit, reward, investment",
    [41] = "Gratitude, luxury, self-sufficiency, culmination",
    [42] = "Manifestation, financial opportunity, new job",
    [43] = "Practical, homely, motherly, down-to-earth, security",
    [44] = "Balance, adaptability, time management, prioritisation",
    [45] = "Control, stability, security, possession, conservatism",
    [46] = "Generosity, charity, giving, prosperity, sharing wealth",
    [47] = "Apprenticeship, education, quality, engagement",
    [48] = "Wealth, inheritance, family, establishment, retirement",
    [49] = "Efficiency, routine, conservatism, methodical",
    [50] = "Security, control, power, discipline, abundance",
    [51] = "Raw power, victory, break-throughs, mental clarity",
    [52] = "Painful separation, sorrow heartbreak, grief, rejection",
    [53] = "Conflict, tension, loss, defeat, win at all costs, betrayal",
    [54] = "Betrayal, deception, getting away with something, stealth",
    [55] = "Depression, nightmares, intense anxiety, despair",
    [56] = "Talkative, curious, mentally restless, energetic",
    [57] = "Quick thinker, organised, perceptive, independent",
    [58] = "Indecision, choices, truce, stalemate, blocked emotions",
    [59] = "Contemplation, recuperation, passivity, relaxation, rest",
    [60] = "Regretful but necessary transition, rite of passage",
    [61] = "Isolation, self-imposed restriction, imprisonment",
    [62] = "Back-stabbed, defeat, crisis, betrayal, endings, loss",
    [63] = "Opinionated, hasty, action-oriented, communicative",
    [64] = "Clear thinking, intellectual power, authority, truth",
    [65] = "Inspiration, power, creation, beginnings, potential",
    [66] = "Preparation, foresight, enterprise, expansion",
    [67] = "Disagreement, competition, strife, tension, conflict",
    [68] = "Challenge, competition, perseverance",
    [69] = "Courage, persistence, test of faith, resilience",
    [70] = "Enthusiasm, exploration, discovery, free spirit",
    [71] = "Exuberance, warmth, vibrancy, determination",
    [72] = "Future planning, progress, decisions, discovery",
    [73] = "Celebration, harmony, marriage, home, community",
    [74] = "Public recognition, victory, progress, self-confidence",
    [75] = "Speed, action, air travel, movement, swift change",
    [76] = "Burden, responsibility, hard work, stress, achievement",
    [77] = "Energy, passion, lust, action, adventure, impulsiveness",
    [78] = "Natural-born leader, vision, entrepreneur, honour"
}

function get_channel(name)
  local channel
  if name:find("gtell") then
    channel = "gtell"
  elseif name:find("ftalk") then
    channel = "ftalk"
  elseif name:find("clantalk") then
    channel = "clantalk"
  elseif name:find("gclan") then
    channel = "gclan"
  elseif name:find("spouse") then
    channel = "spouse"
  else
    channel = nil -- or handle error
  end
  return channel
end

function robbotCommand(name,line,wildcards)
    local channel = get_channel(name)
    rune.dbg("Firing command from trigger: ".. name.." with line: "..line.." from channel: "..channel)
    local ch = wildcards[1]
    local cmd = wildcards[2]
    local arg = wildcards[3]
    local isAFK = isAFK()
    if isAFK then rune.send_raw("afk") end
    if ch == "Spouse" or ch == "You" then ch = char.base.name end
    if cmd == "7ball" then exec7ball(channel,ch,arg) end
    if cmd == "8ball" then exec8ball(channel,ch,arg) end
    if cmd == "shuffletarot" then shuffleTarot(channel,ch) end
    if cmd == "drawtarot" then drawTarot(channel,ch) end
    if cmd == "fortune" then execFortune(channel,ch) end
    if cmd == "mdb" then mdbSearch(channel,ch,arg) end
    if cmd == "goatse" and channel == "spouse" then
        local subject = "To "..arg.." with love, from "..ch
        execSendNote(channel,arg,subject,goatsebody)
    end
    if cmd == "spamnote" and channel == "spouse" then
        local subject = "SPAM DELIVERY from "..ch
        execSendNote(channel,arg,subject,spambody)
    end
    if isAFK then rune.send_raw("afk") end
end

function exec7ball(channel,ch,arg)
    if not arg or arg == "" then return end
    local response = badballresponses[math.random(#badballresponses)]
    rune.send_raw(channel.." "..ch.." asks: @C[@G"..arg.."@C] $CMagic 7-ball Response: @C[@G"..response.."@C]$C")
end

function exec8ball(channel,ch,arg)
    if not arg or arg == "" then return end
    local response = ballresponses[math.random(#ballresponses)]
    rune.dbg(channel.." "..ch.." asks: ["..arg.."] Magic 8-ball Response: ["..response.."]")
    rune.send_raw(channel.." "..ch.." asks: @G[@M"..arg.."@G] $CMagic 8-ball Response: @G[@M"..response.."@G]$C")
end

function execFortune(channel,ch)
    local response = fortuneresponses[math.random(#fortuneresponses)]
    rune.send_raw(channel.." "..ch.." opens a fortune cookie and reads: @C[@Y"..response.."@C]$C")
end

function execSendNote(channel,recipient,subject,body)
    -- Sent a note on personal board
    -- Body can be a string or a table of strings
    if not recipient or recipient == "" then rune.echo("arg not set") return end
    rune.send_raw("board personal")
    rune.send_raw("note write "..recipient)
    local tbody = {}
    if type(body) == "string" then
       rune.echo("Body is a string:"..body) 
       tbody = string.split(body, "\n")
    else
       tbody = body
    end
    rune.send_raw(subject)
    for _, line in ipairs(tbody) do
        rune.send_raw(line)
    end
    rune.send_raw("END")
    rune.send_raw("P")    
end

function shuffleTarot(channel,ch)
    -- Return a table of numbers from 1 to 78 in random order
    if channel ~= nil and ch ~= nil then
        if ch == getGMCP("char.base.name") then
            rune.send_raw(channel.." "..getGMCP("char.base.name").." carefully shuffles a deck of Tarot cards.")
        else
            rune.send_raw(channel.." At the request of "..ch..", "..getGMCP("char.base.name").." carefully shuffles a deck of Tarot cards.")
        end
    end
    local tarotDeck = {}
    for i = 1, 78 do
        tarotDeck[i] = i
    end
    for i = #tarotDeck, 2, -1 do
        local j = math.random(i)
        tarotDeck[i], tarotDeck[j] = tarotDeck[j], tarotDeck[i]
    end
    return tarotDeck
end

function drawTarot(channel,ch)
    -- Draw a card from the tarot deck
    if #tarotRemaining == 0 then
        rune.send_raw(channel.." "..ch.." has drawn all the cards from the Tarot deck. Please shuffle again.")
        return
    end
    local cardIndex = table.remove(tarotRemaining, 1)
    local cardName = TarotName[cardIndex]
    local cardMeaning = TarotPrimary[cardIndex]
    if ch ~= "Iliad" then
        rune.send_raw(channel.." Iliad draws a Tarot card for "..ch..": @C[@W"..cardName.."@C] $CMeaning: '"..cardMeaning.."'.")
    else
        rune.send_raw(channel.." Iliad draws a Tarot card to reveal: @C[@W"..cardName.."@C] $CMeaning: '"..cardMeaning.."'.")
    end

end

function mdbSearch(channel,ch,searchTerm)
    -- Search the mob database for a term
    if channel ~= nil and ch ~= nil then
    local mobdetail = externSearchMobDB(searchTerm)
        if mobdetail then 
            rune.send_raw(channel.." @GResult ".. mobdetail.."$C")
        else
            rune.send_raw(channel.." No results found for @C[@W"..searchTerm.."@C]$C")
        end
    end
end

rune.echo("Initializing... shuffling tarot deck...")
math.randomseed(os.time())
tarotRemaining = shuffleTarot(nil,nil)

require("aardrune/triggers/robbot_triggers")      
      