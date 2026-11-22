---
type: mechanic
status: draft
aliases: []
in-game:
  - src/data/balance.lua
tags:
  - lore/mechanic
  - game/balance
game_kind: balance
game_id: balance
player_max_health: 100
player_max_shield: 100
player_max_energy: 100
player_energy_recharge: 10
player_shield_recharge_rate: 5
player_shield_recharge_delay: 2
player_move_speed: 200
player_inventory_size: 8
max_weapon_level: 10
enemy_level_scaling: 0.15
chunks_per_level: 2
enemy_spawn_chance: 0.55
max_enemies_per_chunk: 5
base_jump_range: 0.3
base_max_fuel: 3
fuel_per_jump: 1
start_location: "[[Kepler Reach]]"
home_location: "[[Drift Station]]"
---

# Global Balance

Numbers that apply to the whole game rather than to one thing.

| Property | Meaning |
|---|---|
| `player_*` | The player's base stats before gear upgrades; move speed in pixels per second; shield starts recharging `player_shield_recharge_delay` seconds after the last hit |
| `max_weapon_level` | How many times one weapon can take a [[Weapon Upgrade]] |
| `enemy_level_scaling` | Each enemy level above 1 adds this fraction to health and damage |
| `chunks_per_level` | Enemies gain a level for every this many chunks from the landing site (plus the planet's `level_bonus`) |
| `enemy_spawn_chance`, `max_enemies_per_chunk` | How crowded each 512 px chunk is |
| `base_jump_range`, `base_max_fuel`, `fuel_per_jump` | Travel on the [[Star Map]] (map units are 0 to 1 across) |
| `start_location`, `home_location` | Where a new game starts, and where you refuel and get towed to |
