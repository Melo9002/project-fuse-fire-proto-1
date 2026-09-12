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
| `MapValidator` | Reports whether runtime map and spawn data can support a battle | Adding legality rules shared by handmade and generated maps |
| `TerrainFeature` | Inspector metadata for authored obstacles | Declaring cover without relying on node names or dimensions |
| `ElevatedSurface` | Inspector metadata that produces elevated walkable cells | Authoring rooftops, platforms, or bridges |
| `ElevationPath` | Produces a sequence of rising walkable cells | Authoring stairs and ramps without special unit movement |
| `TraversalLink` | Converts an authored ladder connection into map data | Connecting terrain that normal height rules cannot join |
| `GridManager` | Cell/world conversion, map data, and separate unit occupancy | Looking up terrain or who occupies a cell |
| `Pathfinder` | A* routes and breadth-first movement range | Changing terrain traversal |
| `CombatRules` | Faction, range, and line of sight | Changing legal attack targets |
| `FactionRules` | Relationships between player, ally, enemy, and neutral | Changing who is hostile or friendly |
| `UnitAction` subclasses | Resource validation and action effects | Changing costs or effects |
| `UnitStats` | HP, AP, defense, defeat signals | Changing health or resource rules |
| `TacticalUnit` | Path animation, defeat relay, health-display creation | Changing unit movement or presentation |
| `AIController` | Chooses among legal attacks, movement, and defense | Changing enemy priorities or difficulty |
| UI and visualizers | Display state and forward input | Changing feedback and presentation |
| `TacticalCamera` | Bounded pan, zoom, and rotation | Changing how the battlefield is viewed |
| `BattleLevel` | Builds selected teams before starting combat | Changing how a match is assembled |
| `SpawnZone` | Supplies ordered spawn transforms and faction data | Changing where a generated team may spawn |
| `UnitPortraitBar` | Mirrors the friendly roster and synchronizes selection | Changing roster-level battle UI |
| `UnitPortrait` | Displays one unit's HP, AP, and UI state | Changing the contents of a portrait card |
| `UnitSelectionVisualizer` | Applies the world outline to the selected friendly | Changing selection feedback in the battlefield |
| `DebugTools` | Pauses the battle, displays runtime data, and changes test control ownership | Adding developer-only battle inspection tools |
| `ShotTrajectoryVisualizer` | Draws the combat validator's exact shot segment | Diagnosing range, cover, and LOS decisions |

## Match setup and spawning

`MatchSetup` collects two independent counts and configures a new `BattleLevel`. The level asks each `SpawnZone` for the requested number of marker transforms, instantiates the shared tactical-unit scene, fills the turn rosters, and adds one AI controller per enemy. Only then does it tell `BattleController` to scan and start the match.

Unit coordinates do not live in spawning code. Handmade `SpawnZone` markers are converted into faction-keyed cells inside `MapData`; a future generator can supply the same data without scene markers. `BattleLevel` still uses authored transforms to instantiate the current Beans, while map validation uses the reusable cell representation.

## Battlefield validation

After authored geometry has become `MapData`, `BattleController` asks `MapValidator` to inspect it before registering units or starting turns. Validation is read-only and returns a `MapValidationResult` containing structured `MapValidationIssue` records. Each issue has a stable code, readable message, and an optional grid coordinate.

The validator checks cell values and path-graph parity, LOS-index consistency, traversal endpoints and connections, unique walkable spawn cells, requested team capacity, and routes between every player/enemy spawn pair. The handmade test map passes through this same boundary that a procedural generator will use. Invalid data remains available for diagnosis, but combat does not start.

## Portrait selection

After units are registered, `BattleController.units_registered` gives the portrait bar the current friendly roster. Each portrait observes its own unit's HP, AP, and defeat signals. Portrait clicks ask `TurnManager` to select the unit; battlefield clicks use that same method. Both paths are reflected back through `active_unit_changed`, so the UI never keeps a separate selection.

Exhausted and dead portraits remain visible but cannot be selected. A dead portrait remains as a record after its world unit leaves the active roster.

`UnitSelectionVisualizer` listens to the same `active_unit_changed` signal and applies a thin material overlay to every mesh below the selected friendly. It clears the previous overlay before applying the next one and does not outline AI units during the enemy phase. This keeps selection feedback separate from unit rules and supports future unit scenes with multiple meshes.

`TurnManager` observes AP for every friendly in the dynamic roster. When the selected unit reaches zero, it waits for any movement to finish and searches forward through the roster, wrapping once and skipping dead or exhausted units. If nobody can act, it emits `player_actions_exhausted`; the HUD emphasizes End Turn while the phase stays open for inspection.

`Pathfinder`, `CombatRules`, `MapBuilder`, and actions are code objects rather than scene nodes. `RefCounted` lets Godot release them when no references remain. The battle owns one pathfinder; the scene no longer contains an unused second one.

`MapData` is the runtime terrain description. Every `MapCellData` record stores its coordinate, world position, elevation, walkability, cover type, physical cover height, LOS blocking flag, and movement cost. Authored maps fill it through `MapBuilder`; a procedural generator can later produce the same records without changing gameplay systems. `GridManager.occupancy_map` remains separate because a unit standing on a tile does not change its terrain.

The Y component of a cell coordinate is its elevation level. `GridManager.elevation_step` converts each level into world height, and `MapData` may hold several cells in the same X/Z column. A `TacticalUnit` keeps its registered grid coordinate as logical state, so two units can occupy different floors in one column without model height confusing occupancy. Pathfinder connects horizontal neighbors whose elevation differs by at most one level; larger gaps remain disconnected until an explicit traversal link such as a ladder is supplied.

An authored `ElevatedSurface` contributes regular `MapCellData` records at its declared elevation. Its solid footprint disables the ground beneath it. A `TraversalLink` contributes `TraversalLinkData` to the map and joins two specified cells in the path graph. The current northwest platform is two levels high, so it remains unreachable when its ladder link is removed. Once a unit climbs onto it, movement uses the same cells and rules as the ground.

`ElevationPath` contributes a sequence of cells with increasing Y coordinates. Stairs and ramps therefore share pathfinding rules; only their scene geometry differs. A suspended surface can preserve lower cells in the same X/Z columns, allowing separate units and paths above and below it.

Movement distinguishes crossing a cell from ending on it. Floor cells cost one movement point and accept units. Low cover stays connected, costs two points, and cannot be a destination; the movement path raises the unit by the declared cover height while crossing it. Full cover is disconnected. Every completed Move action still costs one AP.

`CoverVisualizer` draws a short edge inside each reachable destination beside cover while Move mode is active. The edge faces the obstacle, matching directional combat cover. Low and full cover use separate materials, and leaving Move mode clears both.

## Follow one move

1. The Move button calls `BattleController.toggle_move_mode()`.
2. The controller asks `Pathfinder` for cells within the selected unit's budget and filters occupied destinations through `GridManager`.
3. `PathVisualizer` draws yellow cells. Hovering requests an A* path and draws it in blue.
4. `MouseRaycaster` turns a click into a floor hit. The controller verifies the active turn, recomputes the reachable set and path from map data, then creates `MoveAction`.
5. The action spends AP, reserves the destination, and gives the path to `TacticalUnit`.
6. The unit advances each frame and emits `movement_finished` on arrival. The action mode has already returned to neutral.

A **signal** is an announcement: `ap_changed` lets UI update without stats knowing where the AP label lives. An **exported property** is a value or reference wired in Godot's Inspector.

## Follow an attack and a round

Attack mode makes an enemy click call `BattleController.try_attack()`. `CombatRules.evaluate_attack()` returns legality, hit chance, directional cover, and a reason. Clear shots have 100% accuracy, low cover on the target-facing edge gives 50%, and full cover intersecting the line makes the attack illegal. `AttackAction` spends AP and resolves the roll; hits deal full damage and misses deal none. AI attacks use the same controller entry point.

Line of sight reads the terrain description rather than using pathfinding or raw obstacle collisions. Each blocking cell forms a vertical volume from its terrain elevation through its declared cover height. Combat tests the 3D segment between the attacker and target body centers against those volumes. A shot can therefore pass above a wall, while a descending shot that crosses the same wall remains blocked.

`MapData.los_blocking_cells` indexes only terrain that can stop a shot. Map construction rebuilds this index after applying authored features; dynamic terrain should rebuild it after changing LOS flags or heights.

Attack previews derive the destination body center from the same elevated grid cell used by target validation. Low cover is directional and queried on the target's elevation layer, so ground cover does not protect a unit standing on a platform. Touching only the outer boundary or corner of an obstacle does not block a shot.

Authored obstacles declare their cover type and physical height. The current map uses bright 1 m low cover and darker 2 m full cover. Enable `Debug Shots` on `BattleController` to log attempted targets, legality, chance, and the blocking terrain cell when present.

The 32×24 test battlefield is a systems laboratory. Opposing 5-unit spawn zones sit beyond long firing lanes. The center contains full-cover gates and flank pillars, the south contains staggered vault barriers, and the north contains twin platforms. A higher central platform can be reached independently by ramp, stairs, or ladder. A suspended northwest deck also verifies movement and occupancy above and below the same X/Z columns.

At zero HP, stats announce defeat. The unit relays the signal, and the battle removes it from occupancy and the roster before freeing it.

End Turn starts the enemy phase. Every action request passes through `BattleController`, which asks `TurnManager` whether that unit is alive, active, and part of the current faction roster. Rejected actions preserve AP. Move requests also rebuild their path from authoritative map data, so neither UI nor AI can supply a shortcut through blocked terrain.

The current enemy AI repeats a small priority list while it has AP: attack the legal target with the lowest HP; otherwise move once toward the nearest living player; otherwise Defend and finish its activation. Attack legality, hit chance, movement budget, occupancy, AP cost, damage, and defense all come from the same rules and action classes used by player input. The test level also assigns its extended attack range to both teams, so enemies take legal ranged shots instead of approaching to the unit scene's shorter default range. The AI chooses an intention; it does not implement a second version of combat.

Difficulty should later adjust decision policy, such as target scores, position scores, planning depth, or intentional mistakes. It should not bypass action validation or secretly use different movement and combat rules. After the final enemy activation, a new player round begins. AP resets and defense expires at the start of that team's phase. Running out of player AP does **not** automatically end the phase. Removing the final enemy or player ends the battle and displays Victory or Defeat.

The test scene's `DebugTools` node owns developer-only control overrides. Its Inspector switch can remove the tools from play. F3 opens a pause-safe panel, the optional overlay reads battle state without owning it, manual enemy control redirects the active enemy to the normal action UI, and AI-versus-AI mode attaches the same faction-neutral decision policy to player activations. The shot-trajectory option draws the same body-center segment used by `CombatRules`, including illegal attempts, so its visualization cannot drift from LOS geometry. Blocked shots mark the responsible `MapCellData`, while AI controllers publish structured decision records that the debug UI may display without participating in those decisions. These modes change who chooses actions; all requests still pass through ordinary turn and action validation.

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
- Attack-range coloring shows legal cells, while the attack button shows the exact hovered unit chance or blocked reason.
- The global action lock prevents selection, new actions, and phase changes during movement. Attacks and defense are currently immediate, so they do not hold the lock across an animation.
- The base grid assumes an unrotated floor centered on world X/Z. Elevated surfaces add layers above it, but moving or rotating the base is not supported by all conversions and visuals.
- Terrain is scanned only at startup; moving walls later will not rebuild paths.
- Victory and Defeat are text states in the existing turn HUD; a dedicated result screen can come later.

Play a few rounds, choose the rules you want, and then change the relevant owner above.
