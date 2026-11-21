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

register_regex("trg_bypass_start", "^You are bypassing the following areas:$", "triggerBypassCaptureStart", 100, nil, false)
register_regex("trg_bypass_capture", "^\\s+-\\s+(.+)\\s+\\[(\\d+)\\s*-\\s*(\\d+)\\]\\s+\\((\\w+)\\)\\s+\\((\\d+)% - (\\w+)\\)$", "triggerBypassCaptureLine", 100, nil, false)
register_regex("trg_bypass_end", "^You are allowed to bypass (\\d+) areas\\.?$", "triggerBypassCaptureEnd", 100, nil, false)

