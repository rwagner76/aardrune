# Aardrune - Rune MUD Client Add-on Modules

A collection of Lua add-on modules for the [Rune MUD client](https://www.runeclient.com/), designed primarily for use with [Aardwolf MUD](http://www.aardwolf.com/).

## 📁 Project Structure

```
aardrune/
├── init.lua                    # Main entry point - loads all modules
├── README.md                   # This file
│
├── Core Modules
│   ├── robbo_common.lua        # Shared utility functions and constants
│   ├── gmcphandler.lua         # GMCP protocol handler (core dependency)
│   ├── database_common.lua     # Common database operations
│   └── serialize.lua           # Serialization utilities
│
├── Data Modules (read-only lookup tables)
│   ├── spells.lua              # Spell definitions and data
│   ├── recoveries.lua          # Recovery item definitions
│   └── robbo_aardwolf_colors.lua  # Aardwolf color code helpers
│
├── Feature Modules
│   ├── robbo_mobdb.lua         # Mobile (mob) database
│   ├── robbo_gmcp_mapper.lua   # GMCP-based room mapper
│   ├── robbo_equipment.lua     # Equipment tracking
│   ├── robbo_combat.lua        # Combat automation
│   ├── robbo_quest.lua         # Quest tracking
│   ├── robbo_movement.lua      # Movement helpers
│   ├── robbo_bypass.lua        # Bypass/travel management
│   ├── robbo_group.lua         # Group management
│   ├── robbo_clan.lua          # Clan features
│   ├── robbo_statuswin.lua     # Status window display
│   ├── robbo_convenience.lua   # Quality-of-life commands
│   ├── robbot.lua              # Bot-like automation
│   ├── statusbar.lua           # Status bar UI
│   ├── minimap.lua             # Minimap display
│   ├── keypad.lua              # Keypad bindings
│   ├── channels.lua            # Channel management
│   ├── idle.lua                # Idle detection/prevention
│   └── captureNote.lua         # Note capture utility
│
├── Aliases (command shortcuts)
│   ├── common_aliases.lua
│   ├── combat_aliases.lua
│   ├── equipment_aliases.lua
│   ├── mobdb_aliases.lua
│   ├── gmcp_mapper_aliases.lua
│   ├── movement_aliases.lua
│   ├── bypass_aliases.lua
│   ├── quest_aliases.lua
│   ├── spells_and_pots_aliases.lua
│   ├── group_aliases.lua
│   ├── clan_aliases.lua
│   └── statuswin_aliases.lua
│
├── Triggers (automated responses)
│   ├── combat_triggers.lua
│   ├── equipment_triggers.lua
│   ├── mobdb_triggers.lua
│   ├── gmcp_mapper_triggers.lua
│   ├── movement_triggers.lua
│   ├── bypass_triggers.lua
│   ├── quest_triggers.lua
│   ├── spells_and_pots_triggers.lua
│   ├── robbot_triggers.lua
│   └── clan_triggers.lua
│
└── Third-Party Libraries
    ├── cbor.lua                # CBOR serialization (RFC 7049)
    ├── cbor.bignum.lua         # CBOR bignum support
    └── serialize.lua           # MUSHclient table serialization (Nick Gammon)
```

## 🔗 Module Dependencies

### Dependency Graph

```
init.lua
├── robbo_common.lua           ← Base utilities (no dependencies)
├── gmcphandler.lua            ← GMCP handler (no dependencies)
├── statusbar.lua              → gmcphandler
├── channels.lua               → gmcphandler
├── keypad.lua                 → gmcphandler
├── robbot.lua                 → gmcphandler
├── robbo_mobdb.lua            → cbor, gmcphandler
├── robbo_gmcp_mapper.lua      → cbor, gmcphandler
├── robbo_bypass.lua           → gmcphandler
├── robbo_spells_and_pots.lua  → spells.lua, recoveries.lua, gmcphandler
├── robbo_equipment.lua        → cbor, gmcphandler
├── robbo_quest.lua            → gmcphandler
├── robbo_movement.lua         → gmcphandler
├── robbo_combat.lua           → gmcphandler
├── minimap.lua                → gmcphandler
├── robbo_group.lua            → gmcphandler
├── robbo_statuswin.lua        → gmcphandler
└── robbo_convenience.lua      → gmcphandler
```

### Important Notes

1. **`gmcphandler.lua`** is a core dependency used by most feature modules for GMCP data access
2. **`robbo_gmcp_mapper.lua`** provides mapping functionality but is NOT imported by other modules - they interact via `rune.send("mapper ...")` commands
3. **`cbor.lua`** is a third-party library used by `mobdb`, `mapper`, and `equipment` for data persistence
4. **`spells.lua`** and **`recoveries.lua`** are pure data modules with no external dependencies

## 🚀 Installation

1. Place the `aardrune` directory in your Rune client's script directory
2. Ensure `init.lua` is loaded by Rune (via the Scripts panel or auto-load configuration)
3. Configure any required paths in your Rune client settings

## 📝 Configuration

The system uses Rune's built-in configuration system:

```lua
-- Access configuration values
rune.config.get("setting_name")

-- Set configuration values
rune.config.set("setting_name", value)

-- Configuration directory for data files
rune.config_dir .. "/aardrune/data/"
```

Data files are stored in:
- Mob database: `rune.config_dir/aardrune/data/mobdb_serialized.dat`
- Mapper data: `rune.config_dir/aardrune/data/gmcpmapper_serialized.dat`

## 🎨 Color Codes

This package includes `robbo_aardwolf_colors.lua` which provides helper functions for using Aardwolf MUD color codes instead of Rune's native color system.

## 🗺️ Mapper Commands

The GMCP mapper provides extensive room navigation and management:

```
mapper help                          # Show all commands
mapper find <query>                  # Search rooms by name
mapper goto <id/name>                # Navigate to a room
mapper areas [filter]                # List known areas
mapper exits                         # Show exits from current room
mapper portals                       # Show portals from current room
mapper save                          # Force save mapper data
```

See `robbo_gmcp_mapper.lua` for complete command reference.

## 📦 Third-Party Libraries

### CBOR (Concise Binary Object Representation)

- **Author**: Zash
- **Source**: RFC 7049 implementation (https://www.zash.se/lua-cbor.html)
- **Location**: `aardrune/cbor.lua`, `aardrune/cbor.bignum.lua`
- **License**: MIT License
- **Used by**: `robbo_mobdb`, `robbo_gmcp_mapper`, `robbo_equipment`

CBOR is included for data serialization and persistence. See THIRD_PARTY_NOTICES.md for full license text.

### Serialize Library

- **Author**: Nick Gammon (MUSHclient)
- **Source**: http://www.gammon.com.au/forum/?id=4960
- **Location**: `aardrune/serialize.lua`
- **License**: Free to use, modify, and distribute
- **Used by**: `robbo_common`

Simple table serialization utility from the MUSHclient community. See THIRD_PARTY_NOTICES.md for details.

## 🔧 Development Guidelines

### Adding New Modules

1. Create your module in the `aardrune/` directory
2. Keep dependencies minimal - prefer `robbo_common.lua` for shared utilities
3. If your module needs triggers or aliases, place them in the appropriate subdirectory
4. Load your module in `init.lua` in the correct order (after dependencies)
5. Have your module load its own triggers/aliases at the end of the file

Example:
```lua
-- In your new module file
require("aardrune/robbo_common")  -- if needed
require("aardrune/gmcphandler")   -- if needed

-- Your module code here...

-- Load associated triggers and aliases
require("aardrune/triggers/my_module_triggers")
require("aardrune/aliases/my_module_aliases")
```

### Module Independence Principles

- ✅ **Good**: Modules communicate via `rune.send()` commands
- ✅ **Good**: Shared utilities go in `robbo_common.lua`
- ❌ **Avoid**: Direct `require()` of feature modules from other feature modules
- ❌ **Avoid**: Circular dependencies between modules

### Exception: Mapper-MobDB Relationship

The only intentional cross-module dependency is that `robbo_mobdb` may reference mapper functionality, but NOT vice versa. This is managed through command sending rather than direct imports.

## 🐛 Troubleshooting

### Common Issues

1. **Module not loading**: Check that it's listed in `init.lua` after its dependencies
2. **GMCP data missing**: Ensure `gmcphandler.lua` is loaded before modules that use GMCP
3. **Data persistence errors**: Verify write permissions to `rune.config_dir/aardrune/data/`

### Debug Mode

Enable debug output:
```lua
rune.debug = true  -- Set in init.lua
```

## 📄 License

Unless otherwise noted in individual files, this project is provided as-is for personal use.

Third-party libraries retain their original licenses:
- CBOR library: See `cbor.lua` header for license terms

## 🤝 Contributing

When contributing changes:
1. Maintain the module independence principles outlined above
2. Keep trigger/alias files organized in their respective directories
3. Update this README if adding new modules or changing dependencies
4. Test that modules load correctly in the proper order

---

**Last Updated**: 2026-11-07
# aardrune
# aardrune
