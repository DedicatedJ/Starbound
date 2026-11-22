# Blocked items

Items that need a decision or action from the repository owner. Work continues on everything else.

## 1. Project name

- **Needed:** decide whether to keep "Starbound" / "Starbound Legacy" or rename.
- **Why:** "Starbound" is an existing commercial game by Chucklefish in the same genre (space exploration action RPG). Shipping under this name is a likely trademark problem.
- **Affects:** all steps (title screen, README, `conf.lua` window title and save identity). Renaming later is a search and replace plus a save folder migration.
- **Date:** 2026-11-22

## 2. Story, puzzle and ship content review

- **Needed:** review the narrative, puzzles, planets and ship upgrade content drafted for the full README vision, and replace or approve it.
- **Why:** the README gives only the premise (inherited star map, the Arkadia, the Void Collapse). The characters, story beats, endings, puzzle designs and upgrade tree are original drafts written to make the game complete. They live in data files under `src/data/` so they can be edited without touching game code.
- **Affects:** steps 11 to 14.
- **Balance is untested by real play.** Enemy levels, drop rates, upgrade costs and the Rift's difficulty were tuned on paper (for example the Rift was lowered from level bonus 5 to 3 after estimating that a level 7 drone swarm would kill a fully upgraded player in about 2.5 seconds). A few full play-throughs are needed to tune `src/data/galaxy.lua`, `src/data/upgrades.lua` and the drop tables in `src/entities/enemy.lua`.
- **Date:** 2026-11-22
