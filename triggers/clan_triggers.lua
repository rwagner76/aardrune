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

local function no_script_handler()
    return nil
end

register_regex("trg_clan_roster_member", "\\d+ (\\w+).+\\d+ \\w+ .+\\s+\\d+ \\w+ \\d+$", "triggerClanRosterMember", 100, nil, false)
register_regex("trg_clan_roster_end", "^\\d+ members counted.$", "triggerClanRosterEnd", 100, nil, true)
register_regex("trg_quest_winner", "^Global Quest: Global Quest # \\d+ has been won by (\\w+) - (\\d+)", "triggerGQWinner", 100, nil, false)

rune.trigger.disable("trg_clan_roster_member")
rune.trigger.disable("trg_clan_roster_end")

