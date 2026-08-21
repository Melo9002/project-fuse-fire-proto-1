# 🔥 Project FuseFire

**Project FuseFire** is a prototype 3D tactical grid engine built with **Godot 4**.

The project explores a flexible, mathematically-driven approach to tactical movement and battlefield interaction, with the goal of keeping gameplay logic independent from visual assets and level-specific implementation details.

The core design principles are:

* **Separation of concerns**
* **Runtime flexibility**
* **Deterministic grid calculations**
* **Delta-time-based movement**
* **Procedural visualization**

> 🚧 **Prototype status:** FuseFire is an experimental gameplay prototype. The architecture and systems are actively evolving.

---

## 🎯 What Is FuseFire?

FuseFire started as an experiment in building a **3D tactical battlefield from the ground up**, rather than relying on manually placed tile objects.

Instead of treating every tile as a physical object in the scene, the battlefield is represented mathematically. The game can determine which grid cell the player is pointing at, calculate its center, and translate units between cells without requiring every possible tile position to exist as a separate node.

This makes the system considerably easier to extend toward larger maps, procedural environments, pathfinding, and eventually more complex tactical mechanics.

---

## 🧩 Current Architecture

### 1. Mathematical Grid Backend

The grid is treated as a logical system rather than a collection of manually placed objects.

**Dynamic Grid Layout**

Grid boundaries are calculated from the battlefield geometry at runtime, allowing the logical grid to adapt to the dimensions of the map.

**Cell-Center Snapping**

Continuous 3D positions obtained from mouse interaction are converted into discrete grid coordinates using floor-based calculations. The resulting position is then snapped to the center of the corresponding cell.

In other words:

```text
Mouse Position
      ↓
Physics Raycast
      ↓
World-Space Hit Position
      ↓
Grid Coordinate
      ↓
Cell Center
```

---

### 2. Gameplay & Input Framework

#### `BattleController`

`BattleController` acts as the main orchestration layer between player input, battlefield state, and active units.

Its responsibilities currently include:

* Processing player interaction
* Determining targeted grid cells
* Coordinating movement commands
* Managing the interaction between the grid and tactical units

The project uses **strictly typed GDScript** wherever practical to keep gameplay code predictable and easier to maintain.

#### `TacticalUnit`

Units are responsible for their own movement and local state.

Movement is calculated using delta-time-based interpolation with `move_toward()`, allowing movement speed to remain consistent regardless of frame rate.

```text
Movement Command
       ↓
Target Cell
       ↓
World Position
       ↓
TacticalUnit
       ↓
Delta-Time Movement
```

---

### 3. Tactical UX & Visual Overlays

#### `GridVisualizer`

The tactical grid is generated procedurally using Godot's `ImmediateMesh`.

This avoids the need to manually create and position large numbers of mesh objects while providing a lightweight visual representation of the battlefield grid.

The grid can also be toggled at runtime.

#### `GridCursor`

`GridCursor` provides immediate visual feedback when the player moves the mouse across the battlefield.

Each frame, it:

1. Performs a physics query from the camera through the mouse position.
2. Determines the 3D position being targeted.
3. Converts that position into a grid cell.
4. Snaps the cursor to the center of that cell.

The result is a tactical cursor that follows the logical grid rather than simply following the mouse in world space.

---

## 🎮 Controls

| Action                      | Input      | Result                                                   |
| --------------------------- | ---------- | -------------------------------------------------------- |
| **Hover Selection**         | Mouse Move | Snaps the `GridCursor` to the targeted tile center       |
| **Issue Move Command**      | Left Click | Moves the active `TacticalUnit` toward the selected tile |
| **Toggle Tactical Overlay** | `TAB`      | Toggles the procedural grid visualization                |

---

## 🛠️ Tech Stack

| Component         | Technology                            |
| ----------------- | ------------------------------------- |
| **Engine**        | Godot 4+                              |
| **Language**      | GDScript                              |
| **Code Style**    | Strictly Typed GDScript               |
| **Physics**       | Godot 3D Physics / Direct Space State |
| **Raycasting**    | `intersect_ray()`                     |
| **Grid Math**     | `Vector3` / `Vector3i`                |
| **Visualization** | `ImmediateMesh`                       |
| **Movement**      | Delta-time-based interpolation        |

---

## 🏗️ Current Systems

The current prototype contains the following foundational systems:

* [x] Runtime grid calculation
* [x] Grid cell coordinate conversion
* [x] Cell-center snapping
* [x] 3D mouse-to-world raycasting
* [x] Procedural grid visualization
* [x] Tactical grid cursor
* [x] Tactical unit movement
* [x] Delta-time-based movement
* [x] Tactical overlay toggle
* [x] Strictly typed gameplay scripts

---

## 📈 Next Milestones

The prototype is currently focused on establishing the underlying tactical framework. Planned systems include:

* [ ] Multi-layer 3D grid coordinates using `Vector3i`
* [ ] Environmental collision filtering
* [ ] Obstacles and blocked grid cells
* [ ] A* pathfinding
* [ ] Tactical movement ranges
* [ ] Unit selection and turn-state management
* [ ] Multiple tactical units
* [ ] Terrain and elevation handling
* [ ] More advanced battlefield visualization

---

## 🧠 Design Philosophy

FuseFire is being built around a simple idea:

> **The battlefield should be data first, visuals second.**

A grid cell shouldn't need to exist as a physical object just because the game needs to know where it is.

By keeping the tactical grid mathematical and allowing visual systems to consume that data, the project can evolve toward more complex gameplay without tying core mechanics to scene structure.

This approach should make it easier to experiment with:

* Procedural battlefields
* Large tactical maps
* Multiple elevation layers
* Pathfinding
* Dynamic obstacles
* Different battlefield visualizations
* More complex tactical rules

---

## 📂 Project Status

**FuseFire is currently a technical prototype.**

The immediate goal is not to build a complete game, but to establish a solid tactical foundation that can support one.

The prototype is deliberately small while the underlying architecture is being tested and refined.

🔥 **The fire has been lit. The rest is engineering.**
