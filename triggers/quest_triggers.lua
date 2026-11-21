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

register_exact("trg_questmob_killed", "QUEST: You have almost completed your QUEST!", "questMobKilled", 100, nil, false)
register_exact("trg_quest_again", "QUEST: You may now quest again.", "triggerQuestTime", 100, nil, false)
register_regex("trg_cp_started", ".+ tells you 'I have selected \\d+ targets for you to hunt, \\w+\\.'", "triggerCampaignStart", 100, nil, false)
register_regex("trg_cp_remaining", "You have .+ left to finish this campaign\\.", "triggerCampaignRemaining", 100, nil, false)
register_regex("trg_cp_complete", "CONGRATULATIONS! You have completed your campaign.", "triggerCampaignComplete", 100, nil, false)
register_regex("trg_cp_need_level", "You will have to level before you can go on another campaign.", "triggerCampaignNeedLevel", 100, nil, false)
register_regex("trg_cp_available", "You may take a campaign at this level.", "triggerCampaignAvailable", 100, nil, false)
register_regex("trg_autotick", "--> TICK <-- \\(.+, Qt: (\\d+)\\)", "triggerAutoTick", 100, nil, false)

