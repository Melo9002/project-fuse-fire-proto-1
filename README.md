\# 🔥 Project FuseFire



Welcome to \*\*Project FuseFire\*\*, a high-performance, strictly-typed 3D tactical grid engine built from the ground up in \*\*Godot 4\*\*. 



This project moves away from traditional, restrictive manual tile placement by leveraging a decoupled, mathematically-driven grid architecture. The core design principles are \*\*separation of concerns\*\*, \*\*runtime flexibility\*\*, and \*\*delta-timed predictability\*\*.



\---



\## 🚀 Current Architecture \& Features



We have successfully established the foundational gameplay loop, input processing layer, and real-time visualization frameworks:



\### 1. The Mathematical Grid Backend

\* \*\*Dynamic Single-Source-of-Truth Layout:\*\* The entire tactical grid is decoupled from physical art assets. Grid boundaries dynamically adapt at runtime to match the dimensions of the map geometry down to the millimeter.

\* \*\*Cell-Center Snapping Engine:\*\* Leverages precise 3D floor algorithms (`floor()` routing) to instantly convert continuous mouse hit positions into perfectly aligned, symmetric grid cell centers.



\### 2. Gameplay \& Input Framework

\* \*\*Strict Type-Safe Controller (`BattleController`):\*\* A specialized orchestration script managing interaction between data states, player inputs, and active battlefield entities with complete compilation-level type guarantees.

\* \*\*Asynchronous Execution (`TacticalUnit`):\*\* Units are autonomous objects responsible for their own physics loops. They handle local space state translation via delta-timed linear interpolation (`move\_toward`), completely eliminating framerate dependency bugs.



\### 3. Tactical UX \& Visual Overlays

\* \*\*ImmediateMesh Procedural Grid (`GridVisualizer`):\*\* Renders crisp, glowing, unshaded wireframe boundaries directly on the GPU without requiring heavy textured meshes or manual level painting.

\* \*\*Real-Time Predictive Cursor (`GridCursor`):\*\* Continuously queries the physics world state on every frame to project a snapped visual marker directly beneath the mouse pointer, providing instant feedback to the player.



\---



\## 🎮 Keyboard \& Mouse Controls



| Action | Input | Result |

| :--- | :--- | :--- |

| \*\*Hover Selection\*\* | `Mouse Move` | Snaps the `GridCursor` to the targeted tile center |

| \*\*Issue Move Command\*\* | `Left Click` | Smoothly translates the active `TacticalUnit` to the target tile |

| \*\*Toggle Tactical Overlay\*\* | `TAB` Key | Instantly flips the visibility of the glowing grid visualizer |



\---



\## 🛠️ Tech Stack \& Implementation Details

\* \*\*Engine:\*\* Godot 4+

\* \*\*Language:\*\* GDScript (Strictly Typed Variant)

\* \*\*Physics Domain:\*\* Direct 3D Space State Raycasting (`IntersectRay`)

\* \*\*Vector Math:\*\* Linear Vector Interpolation scaled via Engine Delta Clocks



\---



\## 📈 Next Milestones On The Horizon

\- \[ ] Implement multi-layered 3D pathfinding databases (`Vector3i` coordinates)

\- \[ ] Add environmental collision masks to safely ignore decorative geometry

\- \[ ] Build obstacle navigation arrays (A\* Pathfinding implementation)

