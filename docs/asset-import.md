# Importing Assets into Fuse Fire

This guide is a starting point for replacing prototype geometry with authored models, textures, rigs, and animations. It is intentionally conservative: keep source assets recoverable, let Godot own generated import metadata, and connect visuals to the existing gameplay data rather than embedding rules in a model.

## Suggested project layout

Create these directories when the first authored assets are ready:

```text
assets/
  characters/
    humanoid_dummy/
      source/       Original `.blend` or interchange source
      models/       Exported `.glb` files
      textures/     PNG, WebP, or other source textures
      materials/    Godot material resources when needed
      animations/   Separate animation sources when needed
  environment/
  props/
```

Godot creates adjacent `.import` metadata and cached data under `.godot/imported/`. Commit the source asset and its `.import` metadata when appropriate, but never hand-edit `.godot/imported/`.

## Recommended character format

Use glTF 2.0 binary (`.glb`) for the first humanoid dummy. It carries the mesh, skeleton, skin weights, materials, and animation tracks in one portable file.

Before export:

- apply or freeze object scale;
- use a consistent real-world scale;
- keep the character upright with a documented forward direction;
- give bones stable names;
- remove unused cameras and lights;
- verify that animation clips have clear names and frame ranges;
- keep the model origin and feet positioned consistently.

Test scale beside the existing unit before changing gameplay dimensions. A visual model can be taller or shorter, but `TacticalUnit.standing_height`, targeting samples, collision, selection, and world-bar offsets must eventually describe that body explicitly.

## Import workflow

1. Copy the `.glb` and its textures into the intended `assets/` directory.
2. Open the Godot editor and wait for import to finish.
3. Select the asset in the FileSystem dock and inspect its Import settings.
4. Confirm materials, animation clips, looping, skeleton, and scale.
5. Change import options if necessary and press **Reimport**.
6. Open the imported scene and check the mesh, rig, and every animation.
7. Create an inherited or wrapper scene for project-specific nodes and scripts. Avoid editing the imported scene as if it were ordinary authored Godot content; reimporting the source may overwrite imported structure.
8. Instance the wrapper beneath the gameplay unit, leaving `TacticalUnit`, stats, actions, occupancy, and mission identity on the gameplay scene.

## First humanoid dummy contract

The Prototype 1 dummy should remain deliberately small in scope:

- idle;
- walk or run;
- attack/fire;
- hit reaction;
- defend stance;
- defeat;
- optional carry pose if Rescue presentation is ready.

The animation controller should respond to gameplay signals. Animations must not decide whether movement, attacks, damage, rescue, or extraction succeed.

Keep the Bean scene available as a debug or alternate visual. The underlying `TacticalUnit` contract should allow either presentation to use the same gameplay rules.

## Collision and selection

Do not automatically use detailed render meshes as tactical collision. Prefer simple explicit shapes for:

- selection and mouse targeting;
- body occupancy;
- projectile or visibility sampling when introduced;
- ragdolls, if added much later.

The current game computes movement and terrain blocking through `MapData`. Imported decorative geometry must not silently create a second source of tactical truth.

## Textures and materials

- Keep source textures at useful working resolution; optimize after profiling.
- Use predictable suffixes such as `_albedo`, `_normal`, `_orm`, and `_emission`.
- Confirm color-space interpretation after import.
- Prefer reusable material resources when several scenes share the same appearance.
- Avoid embedding mission rules, factions, or unit identity exclusively in material names.

## Safe manual editing

Usually safe to edit:

- `.gd`, `.tscn`, `.tres`, `.md`, and source asset files;
- wrapper scenes and project-owned materials;
- import options through Godot's Import dock.

Avoid manually editing:

- `.godot/` cache contents;
- generated files under `.godot/imported/`;
- binary `.glb` files;
- `.import` metadata unless diagnosing a specific import problem and you understand the format.

Commit before a large reimport. That makes scale, material, skeleton, or animation changes easy to review and reverse.
