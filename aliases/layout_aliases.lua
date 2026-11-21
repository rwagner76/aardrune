-- Layout testing and utility aliases

-- Show current layout configuration
rune.alias.exact("layout info", function()
    if layout then
        layout.showConfig()
    else
        rune.echo(acs("@RLayout module not loaded!"))
    end
end)

-- Switch middle pane
rune.alias.regex("^tpane (left|middle|right) (.+)$", function(matches)
    local position = matches[1]
    local paneName = matches[2]
    if layout then
        layout.setPane(position, paneName)
        rune.echo(acs("@GSwitched " .. position .. " pane to '" .. paneName .. "'"))
    else
        rune.echo(acs("@RLayout module not loaded!"))
    end
end)

-- Quick shortcuts for common pane switches
rune.alias.exact("tchat", function()
    if layout then layout.setPane("middle", "chat") end
end)

rune.alias.exact("tgq", function()
    if layout then layout.setPane("middle", "gqmobs") end
end)

rune.alias.exact("tcp", function()
    if layout then layout.setPane("middle", "cpmobs") end
end)

-- Force a specific layout mode (for testing)
rune.alias.regex("^layout (desktop|mobile)$", function(matches)
    local mode = matches[1]
    if layout then
        -- Temporarily override the detection
        if mode == "mobile" then
            layout.detectLayout(80, 40)  -- Force mobile dimensions
        else
            layout.detectLayout(253, 63)  -- Force desktop dimensions
        end
        rune.echo(acs("@GForced " .. mode .. " layout"))
    else
        rune.echo(acs("@RLayout module not loaded!"))
    end
end)
