# Object Rain — milestone 01

A Godot 4 first-person physics playground: ten objects fall into an enclosed arena;
collect five, switch between them, drop them back into the world, and hold Focus
to slow the rain. Built with primitive meshes and the Compatibility renderer.

## Run

1. Install **Godot 4.6.x Standard** (tested with **4.6.3**; .NET is unnecessary).
2. Import `project.godot` in the Project Manager.
3. Press **F6** with `scenes/arena.tscn` open, or **F5** to run the project.
4. Click the game if the mouse is released. Hold Shift immediately, or hold it
   while pressing R, to catch the opening fall in slow motion.

No plugins, downloaded assets, credentials, services, or package installation are required.
From a terminal: `godot --path .` (run from this repository).

| Control | Action |
| --- | --- |
| WASD / mouse | Move / look |
| Space | Jump |
| E | Collect the highlighted object within 3.4 m |
| 1–5 / mouse wheel | Select a slot, including empty slots |
| G | Drop the selected object into clear space ahead |
| Hold Shift | Focus: world at 10% speed, responsive movement and camera |
| R | Reset the arena, inventory, and ten-object rain |
| Escape | Release / capture mouse; click also recaptures |

Pickups select the filled slot. A full inventory leaves the object in the world.
Blocked drops retain the held item; look into open space before dropping a chair.
Releasing the mouse or losing application focus also releases Focus. This releases
input, **not** the world simulation; objects continue falling. R is always available
while input is captured.

## Implemented systems and files

```text
scenes/arena.tscn             Main scene, enclosed arena, lights, player and dummy
scenes/player.tscn            CharacterBody3D, camera, weapon mount, inventory, Focus
scenes/dummy.tscn             Stationary damageable target and visible health label
resources/weapons/*.tres      Five editable weapon definitions and future balance values
scripts/player/player.gd      Movement, look, target ray, pickup, safe drop, slot input
scripts/items/                Definitions, item state, inventory, physical/equipped models
scripts/components/           Health and Focus components
scripts/world/                Arena markings, rain spawner and dummy
scripts/ui/hud.gd             Crosshair, target hint, five slots, status and instructions
tests/milestone_test.gd       Executable gameplay/physics regression checks
export_presets.cfg           Windows Desktop export preset
```

The main scene hierarchy is `ObjectRain → Environment, KeyLight, FillLight,
Arena, Objects, Player, Dummy, HUD`. Arena contains the floor, ceiling and four
walls. `Objects` owns the ten spawned bodies and any subsequently dropped bodies.

`WeaponDefinition` is shared Resource data. `ItemInstance` stores per-object
state such as remaining rounds. `WorldItem` uses a `RigidBody3D`, a conservative
collision shape, CCD and its definition's mass, friction and bounce.
`EquippedWeapon` uses a visual-only model attached to the camera. A pickup claims
the world body once, removes it and transfers the same instance into inventory;
dropping transfers that instance back to exactly one new physical body. There is
no physical copy hidden elsewhere. Slots and selected-object changes emit signals.

The pistol, frying pan, chair, folded umbrella and baseball have distinct primitive
silhouettes and colors. Looking at a reachable object gives it a mint highlight.
Walls, objects and the dummy occlude the targeting ray. Drops use a swept enclosing
sphere, plus overlap checks at the start and destination, to avoid spawning inside
geometry. The conservative check can reject a tight space that might fit the mesh.

Focus changes `Engine.time_scale`. Rigid-body physics follows scaled time. Player
acceleration, gravity, movement and UI messages use real time; mouse motion uses
raw relative input. Scene teardown always restores the time scale. There are no
combat cooldowns or animations yet; future world combat should use scaled `delta`.

Collision layers: **1 Arena**, **2 Player**, **3 Objects**, **4 Targets**.
Player mask: Arena/Objects/Targets. Object mask: all four. Interaction mask:
Arena/Objects/Targets. Visual markings and held objects have no collisions.

Tune movement, sensitivity and pickup/drop distance on `Player`; slow multiplier
on `Player/Focus`; rain height, seed and count (up to ten) on `Objects`; health on
`Dummy/Health`; mass, bounce, color, shape size and future damage values in the
five `.tres` files. The default rain includes two of each kind with seeded rotations
and height variation, so repeated tests are comparable.

## Scope and limitations

This is **only milestone 01**. LMB/RMB combat, charged throws, pistol ammunition
consumption, parries, umbrella blocking, impact damage/stagger, enemy AI/waves,
thirty-object selection phases and progression are not implemented. G is a gentle
drop, not a damaging throw. There are no audio assets or complex effects.

`WeaponBehavior` defines equip, unequip, primary, secondary and throw hooks for
later behavior scripts; primary/secondary are intentionally inactive. Definitions
include the requested initial balancing values and role compatibility: Grunts use
nothing, Scavengers accept lightweight items, and Brutes accept chairs. These rules
are tested without spawning enemies or adding AI.

The dummy exposes `apply_damage(amount, direction, impulse)` and a reusable Health
component with damage, change and death signals. Its health display updates and
clamps at zero. It stays stationary, including after death; no player attack is
bound in this milestone. The test suite exercises its damage API directly.

## Validate

From the repository directory:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 60 --script res://tests/milestone_test.gd
```

The suite loads the actual arena and checks fall/floor collision, pickup rays and
highlights, duplicate prevention, capacity, slot input, state-preserving drops,
wall obstruction, recoverability, Focus physics and movement, camera response,
dummy damage, role compatibility, teardown and HUD placement. It prints a summary
and exits nonzero on a failed check. `--fixed-fps 60` makes the checks fast and
repeatable without changing the project's normal runtime settings.

Manual playtest:

1. Hold Shift and reset. Verify ten objects fall slowly while WASD and mouse remain responsive.
2. Approach and aim at an object. Confirm its highlight and E prompt; collect it.
3. Collect five, switch with all number keys and both wheel directions, then try a sixth.
4. Drop beside open floor, then recover it. Try dropping directly into a wall;
   the object should remain in its slot. Select an empty slot and press G.
5. Release Shift, jump, walk against the walls, release the mouse and recapture it.
6. Reset while Focus is active; the arena should return to ten objects and empty slots.

Linux cloud validation uses Godot 4.6.3; the Compatibility renderer was also run
with software OpenGL. Windows execution and export have not been tested here.
For a Windows build, install matching Godot export templates, select
**Project → Export → Windows Desktop**, and export to `builds/windows/ObjectRain.exe`.
The preset embeds the project data in the executable. Export templates are only
needed for packaging, not for playing in the editor.
