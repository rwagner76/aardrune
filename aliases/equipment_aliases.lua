rune.alias.regex("^updateinventory$", function(matches, ctx)
    aliasUpdateInventory("alias_update_inventory", ctx.line, matches)
end, {name = "alias_update_inventory", priority = 100})

rune.alias.regex("^updateinventory detail ?(all)?$", function(matches, ctx)
    aliasUpdateInventoryDetail("alias_update_inventory_detail", ctx.line, matches)
end, {name = "alias_update_inventory_detail", priority = 100})

rune.alias.regex("^tcancel$", function(matches, ctx)
    clearTempTimers("alias_timer_cancel", ctx.line, matches)
end, {name = "alias_timer_cancel", priority = 100})

rune.alias.regex("^invsearch (.+)$", function(matches, ctx)
    aliasInvSearch("alias_inventory_search", ctx.line, matches)
end, {name = "alias_inventory_search", priority = 100})

rune.alias.regex("^invdisplay (\\w+) ?(.+)?$", function(matches, ctx)
    aliasInvDisplay("alias_inventory_display", ctx.line, matches)
end, {name = "alias_inventory_display", priority = 100})

rune.alias.regex("^invcount (.+)$", function(matches, ctx)
    aliasInvCount("alias_inventory_count", ctx.line, matches)
end, {name = "alias_inventory_count", priority = 100})

--rune.alias.regex("^id(e(n(t(i(f(y)?)?)?)?)?)? (.+)$", function(matches, ctx)
rune.alias.regex("^id (.+)$", function(matches, ctx)
    aliasIdentifyItem(ctx.line,matches)
end, {name = "alias_identify_item", priority = 100})

rune.alias.regex("^iteminfo (\\d+)$", function(matches, ctx)
    aliasItemInfo("alias_item_info", ctx.line, matches)
end, {name = "alias_item_info", priority = 100})

rune.alias.regex("^saveeqset$", function(matches, ctx)
    aliasSaveEqSet("alias_save_eq_set", ctx.line, matches)
end, {name = "alias_save_eq_set", priority = 100})

rune.alias.regex("^q(heal|mana|move)$", function(matches, ctx)
    aliasQuaffPotion("alias_quaff_potion", ctx.line, matches)
end, {name = "alias_quaff_potion", priority = 100})

rune.alias.regex("^(heal|mana|move)pot (.+)$", function(matches, ctx)
    aliasSetPotion("alias_set_potion", ctx.line, matches)
end, {name = "alias_set_potion", priority = 100})

rune.alias.regex("^dumpdesiredeq$", function(matches, ctx)
    aliasDumpDesiredEQ("alias_dump_desired_eq", ctx.line, matches)
end, {name = "alias_dump_desired_eq", priority = 100})

rune.alias.regex("^equipforlevel ?(\\d+)?$", function(matches, ctx)
    aliasEquipForLevel("alias_equip_for_level", ctx.line, matches)
end, {name = "alias_equip_for_level", priority = 100})

rune.alias.regex("^updateinventory search (.+)$", function(matches, ctx)
    aliasUpdateInventorySearch("alias_update_inventory_search", ctx.line, matches)
end, {name = "alias_update_inventory_search", priority = 100})

rune.alias.regex("^eq bag (.+)$", function(matches, ctx)
    aliasEQBag("alias_eq_bag", ctx.line, matches)
end, {name = "alias_eq_bag", priority = 100})

rune.alias.regex("^unbag (\\d+)$", function(matches, ctx)
    aliasUnbag("alias_unbag", ctx.line, matches)
end, {name = "alias_unbag", priority = 100})

rune.alias.regex("^rebag (\\d+)$", function(matches, ctx)
    aliasRebag("alias_rebag", ctx.line, matches)
end, {name = "alias_rebag", priority = 100})

rune.alias.regex("^transport (.+)", function(matches, ctx)
    aliasTransport("alias_transport", ctx.line, matches)
end, {name = "alias_transport", priority = 100})

rune.alias.regex("^showeq (.+)", function(matches, ctx)
    displayDesiredEQ("alias_show_desired_eq", ctx.line, matches)
end, {name = "alias_show_desired_eq", priority = 100})

rune.alias.regex("^addeq (\\d+) (.+)", function(matches, ctx)
    addDesiredEQ("alias_add_desired_eq", ctx.line, matches)
end, {name = "alias_add_desired_eq", priority = 100})

rune.alias.regex("^deleq (\\d+)", function(matches, ctx)
    removeDesiredEQ("alias_del_desired_eq", ctx.line, matches)
end, {name = "alias_del_desired_eq", priority = 100})

rune.alias.regex("^shieldup$", function(matches, ctx)
    configShieldup("alias_shield_up", ctx.line, matches)
end, {name = "alias_shield_up", priority = 100})

rune.alias.regex("^dual$", function(matches, ctx)
    configShieldup("alias_dual_wield", ctx.line, matches)
end, {name = "alias_dual_wield", priority = 100})

rune.alias.regex("^wings (on|off)$", function(matches, ctx)
    configAardwolfOverrides("alias_wings_override", ctx.line, matches)
end, {name = "alias_wings_override", priority = 100})

rune.alias.regex("^helm (on|off)$", function(matches, ctx)
    configAardwolfOverrides("alias_helm_override", ctx.line, matches)
end, {name = "alias_helm_override", priority = 100})

rune.alias.regex("^eq save$", function(matches, ctx)
    saveEQDBToDisk("alias_equipment_save", ctx.line, matches)
end, {name = "alias_equipment_save", priority = 100})

rune.alias.regex("^eq help$", function(matches, ctx)
    aliasEquipmentHelp("alias_eq_help", ctx.line, matches)
end, {name = "alias_eq_help", priority = 100})

rune.alias.regex("^kdb ?(.*)?$", function(matches, ctx)
    aliasKeyDB("alias_keydb_short", ctx.line, matches)
end, {name = "alias_keydb_short", priority = 100})

rune.alias.regex("^keydb ?(.*)?$", function(matches, ctx)
    aliasKeyDB("alias_keydb_long", ctx.line, matches)
end, {name = "alias_keydb_long", priority = 100})

rune.alias.regex("^klist$", function(matches, ctx)
    aliasKList("alias_keydb_list_short", ctx.line, matches)
end, {name = "alias_keydb_list_short", priority = 100})

rune.alias.regex("^keysync$", function(matches, ctx)
    keydbSync("alias_keysync", ctx.line, matches)
end, {name = "alias_keysync", priority = 100})

rune.alias.regex("^dt (.+)$", function(matches, ctx)
    aliasEquipDamtype("alias_equip_damtype", ctx.line, matches)
end, {name = "alias_equip_damtype", priority = 100})
