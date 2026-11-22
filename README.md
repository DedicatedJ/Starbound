# The Last Starchart

A retro-style top-down action adventure with RPG elements, built with LÖVE 2D. All graphics are drawn with shapes; there are no image or audio assets.

## Story

Ten years ago your mother, the explorer Mara Solis, flew into the dark and never came back. Now a courier drone has delivered her ship and her star map, with three words: *Find the Arkadia*, a mythical ship said to be able to bring worlds devastated by the Void Collapse back to life.

The story, characters, puzzles, planets and upgrades were drafted from that premise and live in data files under `src/data/` so they are easy to revise.

## Lore

The game's lore lives in [`lore/`](lore/), an [Obsidian](https://obsidian.md/) vault: one linked note per character, place, item, faction, event and ending, plus a timeline and a list of open questions. Open the `lore` folder as a vault in Obsidian and start at `Home.md`. Change the lore there first, then update the matching file under `src/data/`.

The vault is also where the game's numbers live: weapon, enemy, pickup, upgrade and location stats are note properties, with editable balance tables in `lore/Balance/`. `tools/gen_data.py` turns them into `src/data/*.lua` (it needs Python 3 and PyYAML: `pip install pyyaml`):

```
python tools/gen_data.py           # regenerate src/data from the vault
python tools/gen_data.py --check   # what CI runs: fails if src/data is stale
git config core.hooksPath .githooks   # once per clone: regenerate automatically on commit
```

Do not edit the generated data files by hand; CI rejects them if they differ from the vault.

## Features

- **Six locations** on Mara's star map: the landing planet Kepler Reach, the Drift Station hub, three planets hiding vaults (Cinder, Glacius, Verdant Deep) and the Rift.
- **Procedural worlds:** each planet is an endless, seeded world of biomes (jungle, desert, ice, station decks) streamed in chunks around you. Enemies get tougher the farther you roam.
- **Combat:** five weapons (laser pistol, plasma rifle, a charge-up ion cannon, scatter shot, a piercing void beam), weapon upgrades, and three enemy types: wildlife, pirates and drone swarms.
- **Environmental puzzles:** each vault has its own puzzle: a pylon memory sequence, resonating crystals you shoot, and numbered pressure plates.
- **Ship and gear upgrades:** spend salvage and alien essence at Drift Station on a longer-range jump drive, bigger fuel tanks, Void Shielding, armor, shields and power.
- **Story with multiple endings:** dialogue with Quill and Captain Varro, Mara's logs, and a final choice whose options depend on what you did and learned.
- **Inventory, map and saves:** stacking inventory, a map of explored chunks with the vault marked, and save/load from the pause menu.

## Requirements

- [LÖVE](https://love2d.org/) 11.4 or later (tested with 11.5). LÖVE bundles its own LuaJIT; no separate Lua install is needed.

## Running the Game

1. Install LÖVE from https://love2d.org/.
2. Clone this repository:
   ```bash
   git clone https://github.com/DedicatedJ/Starbound.git
   cd Starbound
   ```
3. Run it from the repository root:

### On Windows (PowerShell)
```powershell
& "C:\Program Files\LOVE\love.exe" .
```

### On macOS
```bash
/Applications/love.app/Contents/MacOS/love .
```

### On Linux
```bash
love .
```

## Controls

| Action | Keys |
|---|---|
| Move | WASD or arrow keys |
| Aim and fire | Mouse, left click |
| Switch weapon | 1 to 5 |
| Use inventory slots 1 to 3 | 6 to 8 |
| Interact (ship, people, terminals, vault pylons) | E |
| Inventory (click to use, right-click to drop) | I |
| Map | M |
| Pause menu (resume, save, load, quit) | Esc |
| Dialogue: continue / choose / skip | Space / 1 to 3 / Esc |
| Enemy AI debug rings | F3 |

On the title screen, Space starts a new game and L loads the saved game.

## How to Play

1. Finish the tutorial on Kepler Reach.
2. Walk to your ship and press E to open the star map. Jump to Drift Station and talk to Quill.
3. Recover the three star map fragments. Each fragment planet has a vault, marked on your map and by an on-screen arrow. Solve its puzzle to open it.
4. Collect salvage and alien essence from enemies and vaults, and buy upgrades at the station terminal. The far planets need the Jump Drive Mk II, and the Rift needs Void Shielding.
5. With all three fragments, jump to the Rift and board the Arkadia.

Each jump uses 1 fuel. Docking at Drift Station refuels the ship, and if you run dry, a distress tow can always bring you back to the station. The HUD shows your current objective in the top right.

## Running the Tests

The harness in `tests/harness` loads the game, simulates keyboard and mouse input, runs unit checks on every module, and plays through the campaign: tutorial, travel, a purchase, a vault fragment, save and load, death, and an ending. It prints a PASS or FAIL line per check and exits with code 0 when everything passes. Runs use a fixed random seed so they are reproducible; to try another, pass it as the third argument, for example `love tests/harness . - 7`. Run it from the repository root. GitHub Actions runs the harness on every push and pull request.

### On Windows (PowerShell)
```powershell
& "C:\Program Files\LOVE\lovec.exe" tests\harness
```

### On macOS
```bash
/Applications/love.app/Contents/MacOS/love tests/harness
```

### On Linux
```bash
love tests/harness
```

## Development

The game is structured as follows:
- `main.lua` - Entry point: game states, input, travel, story events, save and load
- `conf.lua` - LÖVE configuration (window, save folder)
- `src/` - Source code directory
  - `entities/` - Player, enemies and loot
  - `world/` - Procedural chunked worlds (`world.lua`) and vault puzzles (`vault.lua`)
  - `game/` - Campaign session (location, fuel, flags) and upgrade purchasing
  - `ui/` - HUD, inventory, map, pause menu, star map, upgrade shop and dialogue box
  - `save/` - Save file serializer and sandboxed loader
  - `data/` - Editable content: galaxy, story and dialogue, upgrades
  - `utils/` - Utility functions
- `tests/harness/` - Test harness (run with LÖVE, see Running the Tests)

Saves are written to LÖVE's save directory under `last_starchart` (for example `%APPDATA%\LOVE\last_starchart` on Windows).

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run the test harness and make sure it passes
4. Commit your changes (`git commit -m 'Add some amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

This project is licensed under the MIT License; see the [LICENSE](LICENSE) file for details.
