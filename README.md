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

The prototype has weighted 3D paths, low-cover vaulting, directional cover, elevation-aware line of sight, ladders, ramps, stairs, platforms, movement previews, selection, AP, shared actions, faction relationships, attacks, defense, autonomous allied and enemy turns, generated maps, battle results, a tactical camera, and health displays. It does not yet have mission actors, objectives, or a finished tactical ruleset.

Match setup supports zero to five green AI allies. Turns proceed from player to allies to enemies. Allies use the same validated movement, attack, and defense actions as every other combatant, are friendly toward players, and are hostile toward enemies. Allies do not appear in the player portrait selector and cannot be selected manually.

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
godot_console --headless --path . --script res://tests/map_validation_smoke.gd
godot_console --headless --path . --script res://tests/flat_map_generator_smoke.gd
```

The smoke tests load the real battle scene and check terrain data, shared player/AI action validation, movement, AP, attacks, walls, defense, enemy turns, selection UI, and defeat cleanup. Play the scene to check appearance and combat feel.

`MapValidator` checks the completed runtime `MapData` before combat starts. A valid map prints its cell, traversal-link, and spawn-cell totals. Invalid maps report stable issue codes and readable messages for invalid cells, path-state mismatches, stale LOS indexes, broken traversal links, bad or insufficient spawn cells, and disconnected opposing spawn zones. A failed validation leaves the battle in its transition state instead of starting on broken data.

The match setup can launch a deterministic generated map. Enable `USE GENERATED MAP`, enter an integer seed, and start the battle. `FlatMapGenerator` creates the ground, faction spawn cells, seeded tactical cover formations, and accessible rooftops directly as `MapData`; `MapGraphBuilder` derives pathfinding from that data, validation approves it, and units spawn from its cells. Barricades, corners, low walls, and staggered positions rotate and move with the seed while cover density stays comparable. Reusing a seed reproduces spawns, cover, and buildings. Spawn bands and a central route remain clear.

Test the default batch of seeds 1 through 100 without opening a battle scene:

```powershell
godot_console --headless --path . --script res://tests/map_generation_batch_smoke.gd
```

Pass a first seed and number of seeds after `--` to test another reproducible range:

```powershell
godot_console --headless --path . --script res://tests/map_generation_batch_smoke.gd -- 5000 250
```

The batch exits unsuccessfully and lists exact seeds and validation messages if any generated map is structurally invalid. It also rejects scattered layouts when fewer than 75% of cover cells have an orthogonally adjacent cover neighbor.

## Debug tools

Generated maps offer Small (24×20), Medium (32×24), and Large (40×30) sizes in match setup. The size control is disabled for the handmade test map. Floor, grid lines, camera zoom and pan limits follow the selected dimensions.

Blue steel containers occupy 3×2 cells (or the rotated 2×3 footprint), are 2 m tall, and block movement and shots. Their footprints are stored in MapData; visuals read the same cells used by combat. Container roofs are not walkable in this step. Container placement reserves surrounding space and the central corridor, and counts toward the existing cover budget. Seed reproducibility requires the same map size and generator version.

Run `godot_console --headless --path . --script res://tests/container_maps_smoke.gd` to validate 100 seeds per size plus full-team runtime spawning and camera bounds.

Generated maps place solid buildings with 3 m walkable roofs and a ground-to-roof ladder. `GeneratedBuildingExpansion` adds an alternate stair approach where space permits and gives each building a seeded 65% chance of a coherent 2×2 utility floor at 6 m, reached by a second ladder. Stairs use ordinary neighboring cells at heights 1 and 2; the existing one-level step rule connects them to ground and roof. Stairs and upper-floor walls block movement and LOS beneath their surfaces. Reserved approaches keep later cover placement clear. These are exterior routes; interiors, larger upper floors, and smooth generated ramps remain deferred while generation work is paused.

Generated building presentation uses readable concrete walls, a recessed roof cap, doors, window panels, and rooftop utility details. The scene combines cool ambient fill with an angled warm directional light so opposing facades remain visible. These decorative pieces have no gameplay collision; movement, cover, and LOS still come exclusively from `MapData`.

To playtest this 6D slice: run the project with **F5**, enable `USE GENERATED MAP`, choose Medium (32×24), enter seed `12345`, and start a battle. Move a unit to the steps, then click the roof to climb; compare this with the yellow ground ladder. From the roof, use the second ladder to reach the 2×2 utility floor. Check descent, AP use, and attacks at different heights. This seed should report 786 cells and 2 traversal links. Restart with the same size and seed to reproduce the layout. Run `godot_console --headless --path . --script res://tests/generated_buildings_smoke.gd` for 300 seeds plus runtime movement, AP, occupancy, and click-surface checks.

The battle scene's `DebugTools` node exposes `Debug Tools Enabled` in the Inspector. When enabled, a small hint appears at the top right. Press **F3** or **Esc** to toggle the debug panel and pause or resume the battle; **Resume Battle** also closes it. `Show battle-data overlay` displays live round, phase, active-unit, coordinate, HP/AP, movement, range, map-cell, and occupancy data.

`Manual enemy control` stops automatic enemy decisions. During each enemy activation, use the ordinary Move, Attack, and Defend buttons, then press End Turn to advance the enemy queue. `AI controls both teams` is a hands-off simulation mode and cannot be active together with manual enemy control.

`Show shot trajectories` draws the exact body-center line used by combat validation while Attack mode is active and a unit is hovered. Green is a legal clear shot, amber is a legal low-cover shot, and red is illegal. Illegal trajectories remain visible through geometry to reveal where the path crosses an obstacle.

When a shot is blocked, its LOS cell is covered by a translucent red marker. The battle-data overlay reports that cell's coordinate, cover type, and height. `Show AI decision explanations` displays the latest automated actor, chosen action and subject, reason, and actions it considered as alternatives.
