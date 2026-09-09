# Project FuseFire

A 3D tactical combat prototype made in Godot 4.7. Choose independent player and enemy force sizes, then fight on a flat, 20 × 20 grid.

## Play

Import `project.godot` in Godot and press **F5**.

The match setup screen accepts 1–5 player units and 1–5 enemy units. The battlefield spawns them from reusable marker-based spawn zones; team sizes do not need to match.

During battle, the bottom portrait bar mirrors the friendly roster. Each Bean card shows HP, AP, and its selected, ready, exhausted, or dead state. Clicking a ready portrait selects the same unit in the battlefield.

The selected friendly also receives a thin cyan outline in the battlefield. The outline follows selection from either the world or portrait bar and clears during the enemy phase.

When the selected unit spends its final AP, selection advances through the friendly roster to the next living unit with AP. If nobody can act, the game remains in the player phase for inspection and highlights End Turn.

| Control | Effect |
| --- | --- |
| Click a player unit | Select it if it has AP remaining |
| Move, then click a yellow cell | Spend 1 AP to move |
| Attack, then click an enemy | Spend 1 AP if the target is in range and visible |
| Defend | Spend 1 AP to halve incoming damage until the unit's next phase |
| End Turn | End the player phase; enemies act in sequence |
| Tab | Toggle the grid overlay |
| Mouse at screen edge / WASD / arrow keys | Pan the camera within the battlefield |
| Mouse wheel | Zoom in or out |
| Hold middle mouse and drag | Rotate the camera |
| Q / E or Page Up / Page Down | Rotate the camera with the keyboard |

Units start their phase with 2 AP and have 100 HP. Attacks deal 25 damage, or 12 against a defending unit. Attack range uses cardinal grid distance. Every unit uses `UnitStats.speed` for its movement budget. Animation speed is separate.

## Understand the code

Start with [the architecture guide](docs/architecture.md): ownership, the path from a click to an action, cleanup changes, and known limitations.

The prototype has A* paths, typed terrain and cover data, obstacle scanning, movement previews, selection, AP, shared actions, faction relationships, attacks, defense, enemy turns, battle results, a tactical camera, and health displays. Cover data does not affect combat or movement yet, and the project does not yet have elevation, procedural maps, or a finished tactical ruleset.

## Verify changes

With the Godot console executable on your PATH:

```powershell
godot_console --headless --path . --editor --quit
godot_console --headless --path . --script res://tests/battle_smoke.gd
godot_console --headless --path . --script res://tests/match_setup_smoke.gd
godot_console --headless --path . --script res://tests/portrait_bar_smoke.gd
godot_console --headless --path . --script res://tests/map_data_smoke.gd
```

The smoke tests load the real battle scene and check terrain data, movement, AP, attacks, walls, defense, enemy turns, selection UI, and defeat cleanup. Play the scene to check appearance and combat feel.
