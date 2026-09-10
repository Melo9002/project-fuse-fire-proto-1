# Project FuseFire

A 3D tactical combat prototype made in Godot 4.7. Choose independent player and enemy force sizes, then fight on a multilayer 32×24 battlefield.

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

The prototype has weighted 3D paths, low-cover vaulting, directional cover, elevation-aware line of sight, ladders, ramps, stairs, platforms, movement previews, selection, AP, shared actions, faction relationships, attacks, defense, enemy turns, battle results, a tactical camera, and health displays. It does not yet have procedural maps or a finished tactical ruleset.

The 32×24 test battlefield is a systems lab: separated 5v5 spawn zones, long firing lanes, a central gate complex, a southern vault course, twin platforms, a three-route high platform, and stacked decks that allow units above and below the same X/Z position.

Friendly units currently have an 8-tile attack range to make cover testing easier. Enemy units retain the prototype's 3-tile range.

## Verify changes

With the Godot console executable on your PATH:

```powershell
godot_console --headless --path . --editor --quit
godot_console --headless --path . --script res://tests/battle_smoke.gd
godot_console --headless --path . --script res://tests/match_setup_smoke.gd
godot_console --headless --path . --script res://tests/portrait_bar_smoke.gd
godot_console --headless --path . --script res://tests/map_data_smoke.gd
godot_console --headless --path . --script res://tests/combat_cover_smoke.gd
godot_console --headless --path . --script res://tests/vault_smoke.gd
godot_console --headless --path . --script res://tests/battlefield_layout_smoke.gd
godot_console --headless --path . --script res://tests/elevation_smoke.gd
godot_console --headless --path . --script res://tests/vertical_traversal_smoke.gd
godot_console --headless --path . --script res://tests/elevation_combat_smoke.gd
godot_console --headless --path . --script res://tests/battlefield_stress_smoke.gd
godot_console --headless --path . --script res://tests/debug_tools_smoke.gd
```

The smoke tests load the real battle scene and check terrain data, shared player/AI action validation, movement, AP, attacks, walls, defense, enemy turns, selection UI, and defeat cleanup. Play the scene to check appearance and combat feel.

## Debug tools

The battle scene's `DebugTools` node exposes `Debug Tools Enabled` in the Inspector. When enabled, a small hint appears at the top right. Press **F3** or **Esc** to toggle the debug panel and pause or resume the battle; **Resume Battle** also closes it. `Show battle-data overlay` displays live round, phase, active-unit, coordinate, HP/AP, movement, range, map-cell, and occupancy data.

`Manual enemy control` stops automatic enemy decisions. During each enemy activation, use the ordinary Move, Attack, and Defend buttons, then press End Turn to advance the enemy queue. `AI controls both teams` is a hands-off simulation mode and cannot be active together with manual enemy control.

`Show shot trajectories` draws the exact body-center line used by combat validation while Attack mode is active and a unit is hovered. Green is a legal clear shot, amber is a legal low-cover shot, and red is illegal. Illegal trajectories remain visible through geometry to reveal where the path crosses an obstacle.

When a shot is blocked, its LOS cell is covered by a translucent red marker. The battle-data overlay reports that cell's coordinate, cover type, and height. `Show AI decision explanations` displays the latest automated actor, chosen action and subject, reason, and actions it considered as alternatives.
