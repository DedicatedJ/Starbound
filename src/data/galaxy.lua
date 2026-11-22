-- Galaxy layout: the locations on Mara Solis's star map.
-- Drafted content (see BLOCKED.md item 2): names, positions and descriptions can be
-- edited freely. Positions are in map units (0-1); jump range is measured in the same units.
return {
    start = "kepler_reach",
    home = "drift_station",      -- refuel point; always reachable by distress tow when out of fuel

    locations = {
        {
            id = "kepler_reach", name = "Kepler Reach", kind = "planet",
            x = 0.15, y = 0.55,
            biomes = {"jungle", "desert"}, levelBonus = 0,
            description = "Where you set down with your mother's ship. Overgrown and quiet, mostly."
        },
        {
            id = "drift_station", name = "Drift Station", kind = "station",
            x = 0.30, y = 0.45,
            biomes = {"space_station"}, levelBonus = 0, safe = true,
            description = "A trading hub run by Quill, an old drone who knew your mother. Refuel and upgrades."
        },
        {
            id = "cinder", name = "Cinder", kind = "planet",
            x = 0.40, y = 0.72,
            biomes = {"desert", "jungle"}, levelBonus = 1,
            fragment = true, puzzle = "sequence",
            description = "A scorched desert world held by Captain Varro's pirates. The map marks a vault."
        },
        {
            id = "glacius", name = "Glacius", kind = "planet",
            x = 0.58, y = 0.25,
            biomes = {"ice", "desert"}, levelBonus = 2,
            fragment = true, puzzle = "resonance",
            description = "A frozen world with ringing crystal pylons. The map marks a vault."
        },
        {
            id = "verdant_deep", name = "Verdant Deep", kind = "planet",
            x = 0.72, y = 0.72,
            biomes = {"jungle", "ice"}, levelBonus = 3,
            fragment = true, puzzle = "plates",
            description = "A deep jungle that swallowed the last survey team. The map marks a vault."
        },
        {
            id = "the_rift", name = "The Rift", kind = "rift",
            x = 0.88, y = 0.45,
            biomes = {"space_station"}, levelBonus = 3,
            requires = {fragments = 3, upgrade = "void_shielding"},
            description = "The scar left by the Void Collapse. Somewhere inside waits the Arkadia."
        }
    }
}
