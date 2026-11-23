---
type: index
tags:
  - lore/index
---

# The Last Starchart: Lore

Start here. Every lore note is one thing (a person, place, item, event...) filed by what it mainly is, and linked to everything it touches.

## Sections
- **Characters:** [[Mara Solis]], [[The Player]], [[Quill]], [[Captain Varro]], [[Ship Computer]], [[Tamsin Hale]], [[The Last Captain]], [[The First Keeper]]
- **Factions:** [[Varro's Crews]], [[The Lost Survey Team]], [[The Makers]]
- **Places:** [[Kepler Reach]], [[Drift Station]], [[Cinder]], [[Glacius]], [[Verdant Deep]], [[The Rift]], [[The Arkadia]], [[Corvane]]
- **Vaults:** [[Cinder Vault]], [[Glacius Vault]], [[Verdant Vault]]
- **Items:** [[Mara's Ship]], [[Star Map]], [[Map Fragments]], [[Access Key]], [[Void Shielding]], [[Jump Drive Mk II]], [[Alien Essence]], [[Void Beam]]
- **Creatures:** [[Alien Wildlife]], [[Drones]]
- **Concepts:** [[The Void]], [[Void Collapse]], [[The Heart and the Helm]], [[The Loom]], [[The Unmaking]]
- **Documents:** [[Mara's Logs]] (the full arc), [[Mara's Log 1]], [[Mara's Log 7]], [[Mara's Log 18]], [[Mara's Log 26]], [[Mara's Log 31]], [[Mara's Log 38]], [[Mara's Log 44]], [[Mara's Log 47]], [[Mara's Log 52]], [[Mara's Final Recording]]
- **Endings:** [[Dawn of Arkadia]], [[The Keeper's Child]], [[Varro's Crown]]
- **Mechanics** (things with stats but little story): [[Global Balance]], weapons ([[Laser Pistol]], [[Plasma Rifle]], [[Ion Cannon]], [[Scatter Shot]]), pickups ([[Health Crystal]], [[Energy Crystal]], [[Shield Crystal]], [[Weapon Upgrade]], [[Repair Kit]], [[Salvage]]), upgrades ([[Expanded Fuel Tanks]], [[Armor Plating]], [[Shield Capacitor]], [[Power Cell]])
- **Balance views** (Bases tables, editable): `Balance/Weapons`, `Balance/Enemies`, `Balance/Upgrades`, `Balance/Pickups`, `Balance/Locations`

## Working notes
- [[Story Spine]]: the whole story in order, with the plot holes closed
- [[Game Changes Needed]]: game text that still has to catch up with the lore
- [[Timeline]]: what happened, in order
- [[Open Questions]]: holes in the lore, the writing to-do list

## Conventions
- **One note per thing.** Other names go in `aliases`, not in a second note. If something fits two folders (the Arkadia is a ship, a place and a voice), file it by what the player mainly does with it and link to it from everywhere else.
- **Properties on every note:**
  - `type`: character, faction, place, vault, item, creature, concept, document, ending, mechanic
  - `status`: `canon` (approved), `draft` (written but not approved), `idea` (not written into anything yet)
  - `in-game`: where the game uses it (file and table), empty if the game does not use it yet
  - `aliases`, `tags`
- **The story is `canon`.** Every character, place, item, ending, concept and document note was reviewed and approved. The `Mechanics` stat notes stay `draft` until the balance is play-tested. New notes start as `draft` or `idea` and are promoted once approved.
- **Lore leads, the game follows.** Change the lore here first, then update the matching file under `src/data/`. The `in-game` property tells you which file.
- **The vault is the source of the game's numbers.** A note with a `game_kind` property (weapon, enemy, pickup, upgrade, location, balance) is game data: its other properties are the stats. One note holds both the lore (body) and the numbers (properties), so the [[Void Beam]]'s story and its damage are the same note.
  - Balance in the `Balance/` tables or in a note's properties, then run `python tools/gen_data.py` to write `src/data/*.lua`. With the git hook on (`git config core.hooksPath .githooks`) this happens automatically on commit.
  - Never edit the generated files in `src/data/` (`weapons`, `enemies`, `pickups`, `upgrades`, `galaxy`, `balance`); CI fails if they do not match the vault. `src/data/story.lua` (dialogue) is still written by hand.
  - Formulas and behavior (how charging works, enemy AI, level scaling) stay in code. The vault holds the knobs, not what they do.
  - Enemy drop chances are `drop_<pickup id>` properties. Links in data properties (`requires_upgrade`, `start_location`) point at the note, and the generator turns them into ids.
  - The generator checks every value and names the note and property when something is wrong.
- **New notes** start from `_templates/` (Templates core plugin, folder `_templates`).
