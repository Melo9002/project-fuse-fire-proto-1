# How FuseFire works

The useful question when reading the code is: **which script owns this decision?** A scene connects objects; scripts define their behavior.

## Folder map

```text
levels/prototype_map/  Playable scene: map, units, camera, and references
systems/              Battle interaction, turns, and combat rules
systems/grid/         Terrain graph, map setup, occupancy, mouse rays
systems/spawning/     Reusable spawn-zone data
scripts/actions/      Move, Attack, and Defend operations
scripts/components/   UnitStats: HP, AP, defense, player movement budget
units/                Unit scene, movement animation, enemy decisions
ui/                   Buttons, turn/AP display, floating health bars
visualizers/          Grid lines, cursor, paths, and range tiles
tests/                Repeatable check using the actual battle scene
```

Keep this layout while the prototype is small. Add folders when they group a real responsibility.

## Who owns what?

| Script | Responsibility | Change it when… |
| --- | --- | --- |
| `BattleController` | Input, action modes, previews, action requests, defeat cleanup | Changing what clicking or choosing an action does |
| `TurnManager` | Phases, active unit, rosters, rounds | Changing whose turn it is or when AP resets |
| `MapBuilder` | Converts authored geometry into map cells and paths | Changing how a scene or future generator supplies terrain |
| `MapData` / `MapCellData` | Terrain, elevation, cover, LOS, and traversal facts | Asking what a battlefield cell contains |
| `TerrainFeature` | Inspector metadata for authored obstacles | Declaring cover without relying on node names or dimensions |
| `GridManager` | Cell/world conversion, map data, and separate unit occupancy | Looking up terrain or who occupies a cell |
| `Pathfinder` | A* routes and breadth-first movement range | Changing terrain traversal |
| `CombatRules` | Faction, range, and line of sight | Changing legal attack targets |
| `FactionRules` | Relationships between player, ally, enemy, and neutral | Changing who is hostile or friendly |
| `UnitAction` subclasses | Resource validation and action effects | Changing costs or effects |
| `UnitStats` | HP, AP, defense, defeat signals | Changing health or resource rules |
| `TacticalUnit` | Path animation, defeat relay, health-display creation | Changing unit movement or presentation |
| `AIController` | Chooses a nearby player and attacks or approaches | Changing enemy decisions |
| UI and visualizers | Display state and forward input | Changing feedback and presentation |
| `TacticalCamera` | Bounded pan, zoom, and rotation | Changing how the battlefield is viewed |
| `BattleLevel` | Builds selected teams before starting combat | Changing how a match is assembled |
| `SpawnZone` | Supplies ordered spawn transforms and faction data | Changing where a generated team may spawn |
| `UnitPortraitBar` | Mirrors the friendly roster and synchronizes selection | Changing roster-level battle UI |
| `UnitPortrait` | Displays one unit's HP, AP, and UI state | Changing the contents of a portrait card |
| `UnitSelectionVisualizer` | Applies the world outline to the selected friendly | Changing selection feedback in the battlefield |

## Match setup and spawning

`MatchSetup` collects two independent counts and configures a new `BattleLevel`. The level asks each `SpawnZone` for the requested number of marker transforms, instantiates the shared tactical-unit scene, fills the turn rosters, and adds one AI controller per enemy. Only then does it tell `BattleController` to scan and start the match.

Unit coordinates do not live in spawning code. They are scene data under the two spawn zones. A future handmade or generated map can supply different zones without changing `BattleLevel`, but procedural generation itself is outside this task.

## Portrait selection

After units are registered, `BattleController.units_registered` gives the portrait bar the current friendly roster. Each portrait observes its own unit's HP, AP, and defeat signals. Portrait clicks ask `TurnManager` to select the unit; battlefield clicks use that same method. Both paths are reflected back through `active_unit_changed`, so the UI never keeps a separate selection.

Exhausted and dead portraits remain visible but cannot be selected. A dead portrait remains as a record after its world unit leaves the active roster.

`UnitSelectionVisualizer` listens to the same `active_unit_changed` signal and applies a thin material overlay to every mesh below the selected friendly. It clears the previous overlay before applying the next one and does not outline AI units during the enemy phase. This keeps selection feedback separate from unit rules and supports future unit scenes with multiple meshes.

`TurnManager` observes AP for every friendly in the dynamic roster. When the selected unit reaches zero, it waits for any movement to finish and searches forward through the roster, wrapping once and skipping dead or exhausted units. If nobody can act, it emits `player_actions_exhausted`; the HUD emphasizes End Turn while the phase stays open for inspection.

`Pathfinder`, `CombatRules`, `MapBuilder`, and actions are code objects rather than scene nodes. `RefCounted` lets Godot release them when no references remain. The battle owns one pathfinder; the scene no longer contains an unused second one.

`MapData` is the runtime terrain description. Every `MapCellData` record stores its coordinate, world position, elevation, walkability, cover type, physical cover height, LOS blocking flag, and movement cost. Authored maps fill it through `MapBuilder`; a procedural generator can later produce the same records without changing gameplay systems. `GridManager.occupancy_map` remains separate because a unit standing on a tile does not change its terrain.

## Follow one move

1. The Move button calls `BattleController.toggle_move_mode()`.
2. The controller asks `Pathfinder` for cells within the selected unit's budget and filters occupied destinations through `GridManager`.
3. `PathVisualizer` draws yellow cells. Hovering requests an A* path and draws it in blue.
4. `MouseRaycaster` turns a click into a floor hit. The controller checks the destination and creates `MoveAction`.
5. The action spends AP, reserves the destination, and gives the path to `TacticalUnit`.
6. The unit advances each frame and emits `movement_finished` on arrival. The action mode has already returned to neutral.

A **signal** is an announcement: `ap_changed` lets UI update without stats knowing where the AP label lives. An **exported property** is a value or reference wired in Godot's Inspector.

## Follow an attack and a round

Attack mode makes an enemy click call `BattleController.try_attack()`. It asks `CombatRules` whether the target is legal, then `AttackAction` checks AP and applies damage through `UnitStats`. AI attacks use the same entry point. `AttackAction` alone does not check range or walls; gameplay callers should use `try_attack()`.

At zero HP, stats announce defeat. The unit relays the signal, and the battle removes it from occupancy and the roster before freeing it.

End Turn starts the enemy phase. Each AI uses the same Move and Attack gateways as the player, then tells `TurnManager` to advance. After the final enemy, a new player round begins. AP resets and defense expires at the start of that team's phase. Running out of player AP does **not** automatically end the phase. Removing the final enemy or player ends the battle and displays Victory or Defeat.

## Terrain and units are different data

Terrain says where the map allows walking. Occupancy says where units are. Moving a unit never disables terrain points.

| Physics layer | Use |
| --- | --- |
| 1 | Environment: blocks movement scans and shots |
| 2 | Floor: receives ground clicks |
| 3 (mask value 4) | Units: receives unit clicks |

Physics collision layers are separate from visual render layers. Map setup waits briefly for CSG collision bodies before scanning and starting the player phase.

## What this cleanup changed

- Extracted map setup and combat validation from `BattleController`.
- Reused `GridManager` for coordinate conversion instead of maintaining a second battle-controller formula.
- Moved the action HUD into `ui/`, preserving its Godot UID and updating its scene reference.
- Removed SP/resupply, the unused AP component and pip HUD, a debug level script, the unused enemy scene, and interrupted scene-save copies. Playable enemies already use `tactical_unit.tscn` with enemy faction set in the level.
- Removed the unused scene pathfinder, an unconfigured health-bar instance, dead turn-automation helpers, and obsolete occupancy/pathfinder coupling.
- Removed the pathfinding override that let paths escape blocked terrain. Units no longer disable terrain, so routes and ranges now both respect blocked starting cells.
- Shortened comments and removed duplicate defense notifications and delayed movement-overlay clearing.

## Camera

`TacticalCamera` is a pivot above the map. Moving changes the pivot's X/Z position, rotation turns the pivot around its center, and zoom changes the child camera's distance. The pivot is clamped to the floor bounds plus a small margin, so the camera can reveal tiles behind UI without wandering far away.

## Known limits to playtest next

- Paths consider terrain, not intervening units. Friendly/enemy blocking needs a gameplay decision.
- Attack previews cast toward floor height; real attacks cast toward unit height. Around low cover, the red overlay can disagree with a shot.
- The global action lock prevents selection, new actions, and phase changes during movement. Attacks and defense are currently immediate, so they do not hold the lock across an animation.
- The grid assumes a flat, unrotated floor centered on world X/Z. Moving or rotating it is not supported by all conversions and visuals.
- Terrain is scanned only at startup; moving walls later will not rebuild paths.
- Victory and Defeat are text states in the existing turn HUD; a dedicated result screen can come later.

Play a few rounds, choose the rules you want, and then change the relevant owner above.
