# Starbound Legacy

A retro-style action-adventure game with RPG elements, built with LÖVE 2D.

## Game Overview

In Starbound Legacy, you play as a young spacefarer who inherits a mysterious star map from your late parent, a legendary explorer who disappeared years ago. This map is said to lead to the Arkadia, a mythical spaceship capable of terraforming planets and reviving a galaxy devastated by the Void Collapse.

## Features

- Explore diverse planets and space stations
- Engage in fast-paced combat with alien creatures and space pirates
- Solve environmental puzzles and uncover mysteries
- Upgrade your ship and equipment
- Experience a rich narrative with multiple endings

## Requirements

- LÖVE 2D 11.4 or later
- Lua 5.1 or later

## Installation

1. Download and install LÖVE 2D from https://love2d.org/
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/starbound-legacy.git
   ```
3. Navigate to the project directory:
   ```bash
   cd starbound-legacy
   ```

## Running the Game

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

## Running the Tests

The harness in `tests/harness` loads the game, simulates keyboard and mouse input, runs unit checks on the game modules, and plays through the tutorial, death, and restart. It prints a PASS or FAIL line per check and exits with code 0 when everything passes. Run it from the repository root.

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
- `main.lua` - Main game entry point
- `conf.lua` - LÖVE configuration
- `src/` - Source code directory
  - `entities/` - Game entities (player, enemies, etc.)
  - `world/` - World generation and management
  - `ui/` - User interface components
  - `utils/` - Utility functions
- `tests/harness/` - Test harness (run with LÖVE, see Running the Tests)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 