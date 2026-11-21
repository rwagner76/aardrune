# Quick Reference Card

A condensed guide for working with the Aardrune codebase.

---

## 📁 File Organization

```
aardrune/
├── init.lua                    ← Main entry point (edit here to add/remove modules)
├── *.lua                       ← Core modules
├── spells.lua                  ← Pure data (spells)
├── recoveries.lua              ← Pure data (items)
├── triggers/                   ← Auto-response patterns
└── aliases/                    ← Command shortcuts
```

---

## 🔗 Module Loading Order (init.lua)

```
1-2:  Core utilities (robbo_common, gmcphandler)
3-8:  Infrastructure (statusbar, channels, keypad, etc.)
9-21: Feature modules (mobdb, mapper, combat, etc.)
```

**Rule:** Dependencies load before dependents!

---

## ✅ Good Patterns

### Adding a New Module
```lua
-- 1. Create: aardrune/robbo_newfeature.lua
require("aardrune/gmcphandler")  -- if needed

local newfeature = {}
function newfeature.doSomething() end
_G.newfeature = newfeature

-- 2. Load triggers/aliases at end
require("aardrune/triggers/newfeature_triggers")
require("aardrune/aliases/newfeature_aliases")

-- 3. Add to init.lua after dependencies
require("aardrune/robbo_newfeature")
```

### Module Communication
```lua
-- ✅ GOOD: Command-based
rune.send("mapper goto " .. roomID)

-- ❌ BAD: Direct import
local mapper = require("aardrune/robbo_gmcp_mapper")
```

### Using GMCP Data
```lua
-- Available after gmcphandler loads:
char.vitals.hp      -- Current HP
char.base.maxhp     -- Max HP
room.name           -- Current room
group.members       -- Group info
```

---

## 🚫 Anti-Patterns to Avoid

```lua
-- Don't create circular dependencies
-- Don't modify globals directly (char = {})
-- Don't hardcode paths (use rune.config_dir)
-- Don't assume module order beyond init.lua
```

---

## 🔍 Quick Commands

```bash
# Find all requires
grep -h "require.*aardrune" aardrune/*.lua | sort -u

# Check CBOR usage
grep -l "cbor" aardrune/*.lua

# Count lines per module
wc -l aardrune/robbo_*.lua

# List trigger files
ls aardrune/triggers/
```

---

## 📊 Key Modules

| Module | Purpose | Depends On |
|--------|---------|------------|
| `robbo_common.lua` | Shared utilities | None |
| `gmcphandler.lua` | GMCP events | None |
| `robbo_mobdb.lua` | Mob database | cbor |
| `robbo_gmcp_mapper.lua` | Room mapper | cbor |
| `robbo_combat.lua` | Combat automation | gmcphandler |
| `spells.lua` | Spell data | None |
| `recoveries.lua` | Item data | None |

---

## 🐛 Debug Checklist

1. Enable debug: `rune.debug = true`
2. Add logging: `rune.dbg("Module: message")`
3. Check GMCP: `if char.vitals then ...`
4. Verify paths: `rune.config_dir`
5. Reload scripts in Rune client

---

## 📝 Documentation

- **README.md** - Project overview
- **ARCHITECTURE.md** - Design patterns
- **DEPENDENCY_ANALYSIS.md** - Module relationships
- **AI_ASSISTANT_GUIDE.md** - Development guide
- **IMPROVEMENT_PLAN.md** - Action items
- **THIRD_PARTY_NOTICES.md** - CBOR attribution

---

## ⚡ Common Tasks

### Add Trigger
```lua
-- In triggers/myfeature_triggers.lua
rune.trigger.contains("pattern", function(name, line, wildcards)
    mymodule.process(line)
end)
```

### Add Alias
```lua
-- In aliases/myfeature_aliases.lua
rune.alias.add("mf command", function()
    mymodule.execute()
end)
```

### Save Data
```lua
local cbor = require "aardrune/cbor"
local file = io.open(rune.config_dir .. "/aardrune/data/file.dat", "wb")
file:write(cbor.encode(myData))
file:close()
```

---

**Print this page and keep it near your workspace!**
