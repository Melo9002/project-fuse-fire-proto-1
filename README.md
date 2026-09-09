# Project FuseFire

A 3D tactical combat prototype made in Godot 4.7. Two player units and two enemies fight on a flat, 20 × 20 grid.

## Play

Import `project.godot` in Godot and press **F5**.

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

The prototype has A* paths, obstacle scanning, movement previews, selection, AP, shared actions, faction relationships, attacks, defense, enemy turns, battle results, a tactical camera, and health displays. It does not yet have elevation, procedural maps, or a finished tactical ruleset.

## Verify changes

With the Godot console executable on your PATH:

```powershell
godot_console --headless --path . --editor --quit
godot_console --headless --path . --script res://tests/battle_smoke.gd
```

The smoke test loads the real battle scene and checks terrain, movement, AP, attacks, walls, defense, enemy turns, and defeat cleanup. Play the scene to check appearance and combat feel.
