-- Upgrades sold at the Drift Station terminal, paid for with materials.
-- Drafted content (see BLOCKED.md item 2): costs and bonuses can be tuned freely.
-- Ship upgrades are flags on the session; gear upgrades raise player stats.
return {
    {
        id = "jump_drive", name = "Jump Drive Mk II", kind = "ship",
        cost = {salvage = 4, alien_essence = 2},
        description = "Jump range +0.15. Reaches Glacius, Verdant Deep and, later, the Rift."
    },
    {
        id = "fuel_tanks", name = "Expanded Fuel Tanks", kind = "ship",
        cost = {salvage = 3},
        description = "Maximum fuel 3 -> 6."
    },
    {
        id = "void_shielding", name = "Void Shielding", kind = "ship",
        cost = {salvage = 8, alien_essence = 4},
        description = "Hull shielding that can survive the Rift."
    },
    {
        id = "armor_plating", name = "Armor Plating", kind = "gear",
        cost = {salvage = 4},
        bonus = {maxHealth = 25},
        description = "Maximum health +25."
    },
    {
        id = "shield_capacitor", name = "Shield Capacitor", kind = "gear",
        cost = {salvage = 3, alien_essence = 2},
        bonus = {maxShield = 25},
        description = "Maximum shield +25."
    },
    {
        id = "power_cell", name = "Power Cell", kind = "gear",
        cost = {salvage = 2, alien_essence = 2},
        bonus = {maxEnergy = 25, energyRechargeRate = 5},
        description = "Maximum energy +25 and faster energy recharge."
    }
}
