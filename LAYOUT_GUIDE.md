# Layout System Guide

## Overview

The Aardrune layout system provides centralized management of UI panes with support for dynamic switching and responsive layouts based on screen size.

## Key Features

- **Centralized Pane Management**: All pane configuration is handled in one place (`layout.lua`)
- **Dynamic Pane Switching**: Easily swap panes between left, middle, and right positions
- **Responsive Design**: Automatically switches between desktop and mobile layouts based on terminal width
  - Desktop: Full 3-pane layout (width ≥ 100 characters)
  - Mobile: Simplified 2-pane layout (width < 100 characters)
- **Extensible**: New panes can be registered and made available for switching

## Architecture

### Pane Positions

The desktop layout has three configurable positions:
- **Left**: Default is minimap (30 chars wide)
- **Middle**: Default is chat (flexible width)
- **Right**: Default is cpmobs/campaign targets (80 chars wide)

Additional fixed panes in desktop mode:
- Status window (40 chars)
- Group monitor (2fr flex)
- Mapper notes (1fr flex)
- Output area + input line

Mobile layout shows only:
- Minimap (30 chars)
- Middle pane (configurable)
- Output area + input line
- Status bars (vitals/aardstatus)

### Registered Panes

The following panes are pre-registered:
- `minimap` - Rune's ASCII minimap
- `chat` - Filtered channel messages
- `gqmobs` - Global Quest target mobs
- `cpmobs` - Campaign target mobs
- `status` - Character status information
- `group` - Group member list
- `notes` - Mapper room notes
- `output` - Main output buffer

## API Reference

### Core Functions

#### `layout.registerPane(name, title, defaultSize)`
Register a new pane with the layout system.

**Parameters:**
- `name` (string): Unique pane identifier
- `title` (string): Display title (shown in desktop mode header)
- `defaultSize` (number|string): Default size in pixels or flex value (e.g., "2fr")

**Example:**
```lua
layout.registerPane("custom", "My Custom Pane", 50)
```

#### `layout.setPane(position, paneName)`
Switch the pane displayed in a specific position.

**Parameters:**
- `position` (string): One of "left", "middle", or "right"
- `paneName` (string): Name of a registered pane

**Example:**
```lua
layout.setPane("right", "gqmobs")  -- Show GQ mobs in right pane
```

#### `layout.getPane(position)`
Get the currently active pane for a position.

**Parameters:**
- `position` (string): One of "left", "middle", or "right"

**Returns:** string - The pane name

#### `layout.getRegisteredPanes()`
Get all registered panes and their configurations.

**Returns:** table - Table of pane configs indexed by name

#### `layout.setGroupCompact(compact)`
Toggle compact group display mode.

**Parameters:**
- `compact` (boolean): true for compact mode (48 chars), false for normal (68 chars)

#### `layout.showConfig()`
Display current layout configuration (useful for debugging).

### Internal Functions

#### `layout.detectLayout(width, height)`
Automatically detect and apply appropriate layout based on dimensions.
Called automatically when `window_size_changed` hook fires.

#### `layout.apply()`
Apply the current layout configuration to Rune.
Called automatically after pane changes.

## Usage Examples

### Switching Between Quest Types

```lua
-- In your quest module
rune.alias.exact("show gq", function()
    layout.setPane("middle", "gqmobs")
end)

rune.alias.exact("show cp", function()
    layout.setPane("middle", "cpmobs")
end)
```

### Adding a Custom Pane

```lua
-- In your custom module
-- First, create the pane
rune.pane.create("mypanel")

-- Register it with the layout system
layout.registerPane("mypanel", "My Panel", 60)

-- Make it switchable
rune.alias.exact("show mypanel", function()
    layout.setPane("right", "mypanel")
end)
```

### Testing Different Layouts

```lua
-- Force mobile layout for testing
layout.detectLayout(80, 40)

-- Force desktop layout
layout.detectLayout(253, 63)

-- Check current configuration
layout.showConfig()
```

## Commands & Aliases

The following aliases are available for testing and quick switching:

- `layout info` - Show current layout configuration
- `tpane <position> <pane>` - Switch pane (e.g., `tpane right gqmobs`)
- `tchat` - Show chat in middle pane
- `tgq` - Show GQ mobs in middle pane
- `tcp` - Show campaign mobs in middle pane
- `layout desktop` - Force desktop layout
- `layout mobile` - Force mobile layout

## Migration Notes

### From Old System

If you were using the old `updateLayout()` function and global variables:

**Old:**
```lua
middlepane = "chat"
rightpane = "cpmobs"
updateLayout("gqmobs", "cpmobs")
```

**New:**
```lua
layout.setPane("middle", "gqmobs")
layout.setPane("right", "cpmobs")
```

### Removed Globals

The following global variables have been removed:
- `middlepane` - Use `layout.getPane("middle")` instead
- `rightpane` - Use `layout.getPane("right")` instead
- `groupcompact` - Managed internally by layout module

The following function has been removed:
- `updateLayout(middle, right)` - Use `layout.setPane()` instead

## Responsive Behavior

The layout automatically adapts based on terminal width:

- **Width ≥ 100**: Desktop layout with full features
- **Width < 100**: Mobile layout with simplified view

This threshold can be adjusted by modifying the `layout.detectLayout()` function in `layout.lua`.

## Implementation Details

### File Structure

- `layout.lua` - Core layout management module
- `aliases/layout_aliases.lua` - Utility commands for testing

### Loading Order

1. `robbo_common.lua` loads and initializes `layout.lua` early
2. Other modules can then use the global `layout` object
3. Individual modules still call `rune.pane.create()` for their own panes
4. Layout system manages which panes are visible and where

### Hook Integration

The layout system registers for the `window_size_changed` hook provided by Rune, allowing automatic layout switching when the terminal is resized.

## Troubleshooting

### Panes Not Showing

Ensure the pane has been created with `rune.pane.create()` before trying to display it.

### Layout Not Updating

Call `layout.apply()` manually if needed, though most operations do this automatically.

### Mobile Layout Issues

Check terminal width with `layout.showConfig()` to verify detection is working correctly.
