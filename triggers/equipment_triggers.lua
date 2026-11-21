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

register_regex("trg_start_invdata", "^{invdata ?(\\d+)?}$", "startInvData", 10, nil, true)
register_regex("trg_end_invdata", "^{/invdata}$", "endInvData", 10, nil, true)
register_regex("trg_start_eqdata", "^{eqdata}$", "startEqData", 10, nil, true)
register_regex("trg_end_eqdata", "^{/eqdata}$", "endEqData", 10, nil, true)
register_regex("trg_invdata_item", "^(\\d+),(.+)$", "triggerInvDataItem", 10, "invdata", true)
register_regex("trg_invitem", "^{invitem}(\\d+),(.+)$", "triggerInvDataItem", 10, nil, true)
register_regex("trg_invmon", "^{invmon}(.+)$", "triggerInvMon", 10, nil, true)
register_regex("trg_id_no_item", "^You do not have that item.$", "abortIdentify", 10, nil, false)
register_regex("trg_identify_keywords", "^\\| Keywords\\s+: (.+?)\\s+\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_name", "^\\| Name\\s+: (.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_id", "^\\| Id\\s+: (.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_typelevel", "^\\| Type\\s+: (.+?)\\s{2,}Level\\s+:\\s+(\\d+)\\s+\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_worthweight", "^\\| Worth\\s+: (.+?)\\s{2,}Weight\\s+:\\s+(\\d+)\\s+\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_spells", "^\\| Spells\\s+: (.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_wearable", "^\\| Wearable\\s+: (.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_score", "^\\| Score\\s+: (.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_flags", "^\\| Flags\\s+: (.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_continued", "^\\|\\s+: (.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_owner", "^\\| Owned By\\s+: (.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_found_at", "^\\| Found at\\s+: (.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_leads_to", "^\\| Leads to\\s+: (.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_wtype_avgdam", "^\\| Weapon Type: (.+?)\\s{2,}Average Dam :\\s+(\\d+)\\s+\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_inflicts_damtype", "^\\| Inflicts\\s+: (.+?)\\s{2,}Damage Type :\\s+(.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_regex("trg_identify_specials", "^\\| Specials\\s+: (.+?)\\s{2,}\\|$", "triggerIdentifyData", 10, "identify", false)
register_exact("trg_end_identify_section", "+-----------------------------------------------------------------+", "triggerEndIdentifySection", 10, "identify", false)
register_regex("trg_end_identify", "^([^+|].*)$", "triggerEndIdentify", 10, nil, false)

rune.group.disable("identify")
rune.trigger.disable("trg_invdata_item")

