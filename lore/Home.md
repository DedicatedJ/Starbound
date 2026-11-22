---
type: index
tags:
  - lore/index
---

# The Last Starchart: Lore

Start here. Every lore note is one thing (a person, place, item, event...) filed by what it mainly is, and linked to everything it touches.

## Sections
- **Characters:** [[Mara Solis]], [[The Player]], [[Quill]], [[Captain Varro]], [[Ship Computer]]
- **Factions:** [[Varro's Crews]], [[The Lost Survey Team]]
- **Places:** [[Kepler Reach]], [[Drift Station]], [[Cinder]], [[Glacius]], [[Verdant Deep]], [[The Rift]], [[The Arkadia]]
- **Vaults:** [[Cinder Vault]], [[Glacius Vault]], [[Verdant Vault]]
- **Items:** [[Mara's Ship]], [[Star Map]], [[Map Fragments]], [[Access Key]], [[Void Shielding]], [[Jump Drive Mk II]], [[Alien Essence]], [[Void Beam]]
- **Creatures:** [[Alien Wildlife]], [[Drones]]
- **Concepts:** [[The Void]], [[Void Collapse]]
- **Documents:** [[Mara's Log 31]], [[Mara's Log 44]], [[Mara's Log 52]], [[Mara's Final Recording]]
- **Endings:** [[Dawn of Arkadia]], [[The Keeper's Child]], [[Varro's Crown]]

## Working notes
- [[Timeline]]: what happened, in order
- [[Open Questions]]: holes in the lore, the writing to-do list

## Conventions
- **One note per thing.** Other names go in `aliases`, not in a second note. If something fits two folders (the Arkadia is a ship, a place and a voice), file it by what the player mainly does with it and link to it from everywhere else.
- **Properties on every note:**
  - `type`: character, faction, place, vault, item, creature, concept, document, ending
  - `status`: `canon` (approved), `draft` (written but not approved), `idea` (not written into anything yet)
  - `in-game`: where the game uses it (file and table), empty if the game does not use it yet
  - `aliases`, `tags`
- **Everything is `draft` for now.** All of this was drafted from the README premise and has not been approved. Promote a note to `canon` once you sign off on it.
- **Lore leads, the game follows.** Change the lore here first, then update the matching file under `src/data/`. The `in-game` property tells you which file.
- **Mechanics stay in code.** Stats, costs and drop rates live in the game files. Notes describe what a thing *is*, not its numbers.
- **New notes** start from `_templates/` (Templates core plugin, folder `_templates`).
