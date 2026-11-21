local function build_opts(name, priority, group, gag)
    local opts = { name = name, priority = priority or 100 }
    if group then opts.group = group end
    if gag then opts.gag = true end
    return opts
end

local function clean_ctx_line(ctx)
    if ctx and ctx.line then
        if type(ctx.line) == "string" then
            return ctx.line
        end
        if type(ctx.line.clean) == "function" then
            return ctx.line:clean()
        end
    end
    return ""
end

local function resolve_script(script_name, trigger_name)
    local fn = _G[script_name]
    if type(fn) ~= "function" then
        rune.echo(string.format("Missing trigger script '%s' for '%s'", script_name, trigger_name))
        return nil
    end
    return fn
end

local function register_regex(name, pattern, script_name, priority, group, gag)
    rune.dbg("Registering regex trigger: " .. name .. " with pattern: " .. pattern)
    rune.trigger.regex(pattern, function(matches, ctx)
        local script_fn = resolve_script(script_name, name)
        if not script_fn then
            return nil
        end
        return script_fn(name, clean_ctx_line(ctx), matches or {})
    end, build_opts(name, priority, group, gag))
end

local function register_exact(name, line, script_name, priority, group, gag)
    rune.trigger.exact(line, function(matches, ctx)
        local script_fn = resolve_script(script_name, name)
        if not script_fn then
            return nil
        end
        return script_fn(name, clean_ctx_line(ctx), matches or {})
    end, build_opts(name, priority, group, gag))
end

register_regex("trg_robbot_gtell", "^\\(Group.+ (\\w+): '(7ball|8ball|mdb) (.+)'$", "robbotCommand", 100, nil, false)
register_regex("trg_robbot_gtell_noarg", "^\\(Group.+ (\\w+): '(fortune|shuffletarot|drawtarot)'$", "robbotCommand", 100, nil, false)
register_regex("trg_robbot_spouse_me", "^\\((Spouse)\\): (7ball|8ball|goatse|spamnote|mdb) (.+)$", "robbotCommand", 100, nil, false)
register_regex("trg_robbot_spouse_me_noarg", "^\\((Spouse)\\): (shuffletarot|drawtarot)$", "robbotCommand", 100, nil, false)
register_regex("trg_robbot_ftalk_me", "^(You) tell your friends: '(7ball|8ball|goatse|spamnote|mdb) (.+)'$", "robbotCommand", 100, nil, false)
register_regex("trg_robbot_ftalk_me_noarg", "^(You) tell your friends: '(shuffletarot|drawtarot|fortune)'$", "robbotCommand", 100, nil, false)
register_regex("trg_robbot_ftalk_others", "^\\(Friend.+ (\\w+): '(7ball|8ball) (.+)'$", "robbotCommand", 100, nil, false)
register_regex("trg_robbot_ftalk_others_noarg", "^\\(Friend.+ (\\w+): '(shuffletarot|drawtarot|fortune)'$", "robbotCommand", 100, nil, false)
register_regex("trg_robbot_clantalk_me", "^(You) tell the CLAN: '(7ball|8ball|goatse|spamnote|mdb) (.+)'$", "robbotCommand", 100, nil, false)
register_regex("trg_robbot_clantalk_me_noarg", "^(You) tell the CLAN: '(shuffletarot|drawtarot|fortune)'$", "robbotCommand", 100, nil, false)
register_regex("trg_robbot_clantalk_others", "^(\\w+) \\(.+\\) tells the CLAN: '(7ball|8ball|mdb) (.+)'$", "robbotCommand", 100, nil, false)
register_regex("trg_robbot_clantalk_others_noarg", "^(\\w+) \\(.+\\) tells the CLAN: '(shuffletarot|drawtarot|fortune)'$", "robbotCommand", 100, nil, false)
