-- layout.lua - Centralized layout management for Aardrune
-- Handles pane configuration, dynamic switching, and responsive layouts

local layout = {}

-- Internal state
local _panes = {}          -- Registered pane metadata
local _activePanes = {     -- Currently active pane names per position
    left = "minimap",
    middle = "chat",
    right = "cpmobs",
}
local _currentLayout = "desktop"  -- "desktop" or "mobile"
-- Normalize groupcompact to boolean (store may return string)
local storedCompact = rune.store.get("groupcompact")
local _groupCompact = false
if type(storedCompact) == "string" then
    _groupCompact = (storedCompact == "true")
elseif type(storedCompact) == "boolean" then
    _groupCompact = storedCompact
end

-- Pane registry: stores metadata about each available pane
-- Format: { name = "pane_name", title = "Display Title", defaultSize = number_or_string }
local _paneRegistry = {
    minimap = { name = "minimap", title = "", defaultSize = 31 },
    chat = { name = "chat", title = "", defaultSize = nil },  -- flexible
    gqmobs = { name = "gqmobs", title = "Global Quest Targets", defaultSize = 80 },
    cpmobs = { name = "cpmobs", title = "Campaign Targets", defaultSize = 80 },
    status = { name = "status", title = "", defaultSize = 40 },
    group = { name = "group", title = "", defaultSize = "2fr" },
    notes = { name = "notes", title = "", defaultSize = "1fr" },
    output = { name = "output", title = "", defaultSize = nil },
}

--- Register a new pane with the layout system
-- @param name string - Unique pane identifier
-- @param title string - Display title for the pane (used in desktop mode)
-- @param defaultSize number|string - Default size (number for pixels, string for flex like "2fr")
function layout.registerPane(name, title, defaultSize)
    if not name or _paneRegistry[name] then
        rune.dbg("layout: Pane '" .. tostring(name) .. "' already registered or invalid name")
        return
    end
    
    _paneRegistry[name] = {
        name = name,
        title = title or "",
        defaultSize = defaultSize,
    }
    
    rune.dbg("layout: Registered pane '" .. name .. "'")
end

--- Set the active pane for a specific position
-- @param position string - One of "left", "middle", "right"
-- @param paneName string - Name of the registered pane to display
function layout.setPane(position, paneName)
    if not _paneRegistry[paneName] then
        rune.dbg("layout: Cannot set unknown pane '" .. tostring(paneName) .. "'")
        return
    end
    
    if position ~= "left" and position ~= "middle" and position ~= "right" then
        rune.dbg("layout: Invalid position '" .. tostring(position) .. "'")
        return
    end
    
    local oldPane = _activePanes[position]
    _activePanes[position] = paneName
    
    rune.dbg("layout: Swapped " .. position .. " pane from '" .. oldPane .. "' to '" .. paneName .. "'")
    
    -- Rebuild the current layout
    layout.apply()
end

--- Get the currently active pane for a position
-- @param position string - One of "left", "middle", "right"
-- @return string - Current pane name
function layout.getPane(position)
    return _activePanes[position]
end

--- Get all registered panes
-- @return table - Table of registered pane configs
function layout.getRegisteredPanes()
    local result = {}
    for name, config in pairs(_paneRegistry) do
        result[name] = config
    end
    return result
end

--- Calculate appropriate layout based on screen dimensions
-- @param width number - Terminal width in characters
-- @param height number - Terminal height in characters
function layout.detectLayout(width, height)
    local newLayout = "desktop"
    
    if width < 100 then
        newLayout = "mobile"
    end
    
    if newLayout ~= _currentLayout then
        rune.dbg("layout: Layout changed from '" .. _currentLayout .. "' to '" .. newLayout .. "' (" .. width .. "x" .. height .. ")")
        _currentLayout = newLayout
        layout.apply()
    end
end

--- Build desktop layout configuration
-- @return table - Layout config for rune.ui.layout()
local function buildDesktopLayout()
    local groupWidth = 68
    if _groupCompact then
        groupWidth = 48
    end
    
    local rightPaneConfig = _paneRegistry[_activePanes.right]
    local rightTitle = rightPaneConfig and rightPaneConfig.title or ""
    local rightSize = rightPaneConfig and rightPaneConfig.defaultSize or 80
    
    return {
        type = "column",
        children = {
            {
                type = "row",
                size = 17,
                dividers = true,
                children = {
                    {type = "pane", name = _activePanes.left, size = _paneRegistry[_activePanes.left].defaultSize, border = "horizontal", title = ""},
                    {type = "pane", name = _activePanes.middle, border = "horizontal", title = ""},
                    {type = "pane", name = _activePanes.right, size = rightSize, border = "horizontal", title = rightTitle},
                },
            },
            {
                type = "row",
                dividers = true,
                children = {
                    {type = "pane", name = "status", border = "none", size = 36, title = ""},
                    {type = "column", 
                        children = {
                            {type = "pane", name = "output", border = "none"},
                            {type = "input"},
                        },
                    },
                    {type = "column", id = "rightcol", size = groupWidth,
                        children = {
                            {type = "pane", name = "group", size = "2fr", border = "none", title = ""},
                            {type = "pane", name = "notes", size = "1fr", border = "horizontal", title = ""},
                        },
                    },
                },
            },
            {type = "bar", name = "vitals"},
            {type = "bar", name = "aardstatus"},
        },
    }
end

--- Build mobile layout configuration
-- Shows only top row with minimap and one content pane, no side panes
-- @return table - Layout config for rune.ui.layout()
local function buildMobileLayout()
    return {
        type = "column",
        children = {
            {
                type = "row",
                size = 17,
                dividers = true,
                children = {
                    {type = "pane", name = "minimap", size = 30, border = "horizontal", title = ""},
                    {type = "pane", name = _activePanes.middle, border = "horizontal", title = ""},
                },
            },
            {
                type = "row",
                dividers = true,
                children = {
                    {type = "pane", name = "output", border = "none"},
                    {type = "input"},
                },
            },
            {type = "bar", name = "vitals"},
            {type = "bar", name = "aardstatus"},
        },
    }
end

--- Apply the current layout configuration to Rune
function layout.apply()
    local config
    
    if _currentLayout == "mobile" then
        config = buildMobileLayout()
    else
        config = buildDesktopLayout()
    end
    
    rune.ui.layout(config)
    rune.ui.regions.show("toprow")
    
    rune.dbg("layout: Applied " .. _currentLayout .. " layout")
end

--- Toggle group compact mode and refresh layout
-- @param compact boolean - Whether to use compact group display
function layout.setGroupCompact(compact)
    _groupCompact = compact and true or false
    rune.store.set("groupcompact", _groupCompact)
    layout.apply()
end

--- Initialize the layout system
function layout.init()
    rune.dbg("layout: Initializing layout system")
    
    -- Listen for window resize events
    if rune.hooks then
        rune.hooks.on("window_size_changed", function(data)
            if data and data.width and data.height then
                layout.detectLayout(data.width, data.height)
            end
        end)
    end
    
    -- Apply initial layout
    layout.apply()
    
    rune.dbg("layout: Initialization complete")
end

--- Show current layout configuration (for debugging)
function layout.showConfig()
    rune.echo(acs("@c=== Layout Configuration ===@w"))
    rune.echo("Current mode: " .. _currentLayout)
    rune.echo("Left pane:   " .. _activePanes.left)
    rune.echo("Middle pane: " .. _activePanes.middle)
    rune.echo("Right pane:  " .. _activePanes.right)
    rune.echo("Group compact: " .. tostring(_groupCompact))
    rune.echo("")
    rune.echo(acs("@cRegistered panes:@w"))
    for name, config in pairs(_paneRegistry) do
        local size = config.defaultSize or "flexible"
        local title = config.title ~= "" and " [" .. config.title .. "]" or ""
        rune.echo("  - " .. name .. title .. " (size: " .. tostring(size) .. ")")
    end
end

-- Make layout available globally
_G.layout = layout

return layout
