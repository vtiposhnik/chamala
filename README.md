# Object Rain — iteration 02

A Godot 4 first-person physics playground with ten falling props, five inventory
slots, Focus slow motion, and the first three functional weapons. The original
arena, movement, camera, inventory and item-identity systems are retained.

## Run

Use **Godot 4.6.x Standard** (tested with **4.6.3**; no .NET, plugins, downloaded
assets, services or credentials). Import `project.godot`, then press **F5** to run.
From this directory: `godot --path .`.

Click the game if the mouse is released. Hold Shift while pressing F5 **inside
the running game** to reset the rain in Focus and catch falling objects.

| Control | Action |
| --- | --- |
| WASD / mouse | Move / look |
| Space | Jump |
| E | Instantly collect the highlighted object |
| 1–5 / mouse wheel | Select an inventory slot, including empty slots |
| G | Gentle drop (preserved from iteration 01) |
| F | Physical throw of any equipped object |
| LMB | Pistol fire / pan swing / hold and release to throw baseball |
| RMB | Pistol-whip / pan parry / baseball underhand toss |
| R | Reload pistol; **no longer resets the arena** |
| T | Reset dummy to 100 HP, preserving inventory and world objects |
| F5 | Reset arena, inventory, dummy and the ten-object rain |
| Hold Shift | Focus: world at 10% speed, normal-feeling movement and camera |
| Escape | Release / capture mouse; click also recaptures |

Holding LMB repeats pistol shots or pan swings at their configured rates. Switching
weapons or releasing the mouse cancels held attacks, a partial charge, parry and
unfinished reload. Releasing the mouse does not pause the simulation.

## Physics changes

- **Pushing:** CharacterBody3D did not provide a sustained impulse to settled
  RigidBody3D props. Contact-based horizontal impulses now wake only contacted
  bodies. Applied force is bounded, delta-v is capped, and mass/friction determine
  resistance. Thin pans use the leading contact at the character's rounded foot;
  props directly underneath the player are not kicked sideways. Sleeping stays on.
- **Throwing:** F and baseball attacks share a release path, separate from attack
  behavior. Swept-volume and destination overlap checks retain the item when space
  is blocked. Impulses are applied in the first physics integration step, after
  server-side mass is synchronized. Spin is bounded and mass-scaled. The thrower
  is temporarily excluded from collision until the grace period ends and the prop
  clears their body. The same item instance becomes recoverable in the world.
- **Held models:** The old wall ray intentionally hid the weapon mount. It is
  removed. Held meshes now render in an isolated transparent SubViewport with their
  own depth buffer, below the HUD. They have no physics body and cast no shadows.
  Walls cannot clip or hide them, and the inventory stays authoritative.
- **Pickup:** An exact ray takes priority. On a miss, a narrow camera-aligned capsule
  represents a swept sphere; it checks up to twelve candidates, ranks crosshair
  proximity, and validates line of sight for at most four. This catches small balls
  without selecting unrelated objects or reaching through walls. No world-wide
  per-frame object search is used.

## Combat and feedback

| Weapon | Primary | Secondary |
| --- | --- | --- |
| Pistol | 20-damage hitscan, 3 shots/sec, 12-round magazine | 12-damage close-range whip |
| Frying pan | 25-damage melee sweep, 1.6 swings/sec, strong impulse | Frontal parry, 0.25-second active window |
| Baseball | Charged physical throw, up to 30 direct-hit damage | Gentle upward underhand toss |

Pistol reload takes 1.1 world seconds with unlimited reserve ammunition for testing.
Hitscan stops at walls and applies bounded impulses to props. Recoil, a simple
muzzle flash, swing/reload poses and HUD hit markers provide placeholder feedback.

Melee queries execute once per swing and use distance, angle and occlusion checks.
A target can be hit only once per swing. Parry raises/highlights the pan and shows
`PARRY ACTIVE`; success consumes the window and flashes a confirmation. The shared
`CombatController.try_parry(origin, projectile, attacker)` API rejects late/rear
attacks, calls `interrupt_attack()` on a compatible melee attacker, or reflects a
projectile that supports `can_reflect()` and `reflect()`. Physical baseball contact
with a parrying player also invokes this path. There are no enemy attackers yet.

Baseballs use rigid-body gravity, CCD, bounce and friction. Damage combines charge
with normal impact speed, capped at 30. A three-sample pre-contact velocity history
accounts for Godot CCD reducing speed before reporting a contact. The history clears
on contact, and each target is damaged only once per launch, preventing resting-contact
repeats. Landing/sleep disarms the ball; pickup and a new throw start a new launch.
Eligible targets receive a stagger callback. The stationary dummy shows a short
visual stagger and damage flash while its collider remains fixed.

The HUD shows ammo/reload state, baseball charge, active parry, hit damage, and the
target object's mass and speed in m/s. Held items show their mass. The dummy displays
100 HP, incoming damage and an offline/reset message at zero HP.

## Focus timing

The existing Focus movement and camera behavior is unchanged. Player movement uses
unscaled time; world physics uses `Engine.time_scale`. Combat cooldowns, reload,
charge, parry, projectile motion and procedural weapon animation all use **world
seconds**. At 10% speed a 0.25-second parry lasts 2.5 real seconds, and a one-second
charge takes ten real seconds. HUD notifications use real time. Push impulses use
world delta and unscaled intended movement speed, avoiding a tenfold force spike.

Per-item cooldowns survive switching and world/inventory transfers. Unequipping
cancels reload and charge rather than completing them invisibly. Releasing the mouse,
losing application focus, or removing the scene restores normal time.

## Files and tuning

```text
scenes/arena.tscn                 Existing enclosed arena, lights, player, dummy, HUD
scenes/player.tscn                Existing player plus a Combat controller node
scenes/dummy.tscn                 Stationary target using Health
resources/weapons/*.tres          Shared definitions, physics and combat tuning
scripts/player/player.gd          Existing movement + contact push, pickup and release
scripts/items/world_item.gd       Physical props, safe launch, impacts and reflection
scripts/items/equipped_weapon.gd  Isolated held rendering and procedural feedback
scripts/items/item_instance.gd    Persistent per-item ammo and cooldown
scripts/items/weapon_behavior.gd  Equip/unequip/primary/secondary/reload/parry hooks
scripts/combat/                  Controller, shared hit queries, three weapon behaviors
scripts/components/              Health and unchanged Focus controller
scripts/world/dummy.gd           Damage flash, stagger, health label and reset
scripts/ui/hud.gd                 Inventory, aiming, combat status and debug readout
project.godot                    Input actions and Compatibility renderer
export_presets.cfg               Windows Desktop export preset
```

Physics and combat parameters are exported on `WeaponDefinition`: mass, friction,
bounce, throw impulse/speed/spin/grace, damage, rate, ammo, reload, melee range/arc,
parry window, charge duration, impact-speed threshold and stagger time. Player
push force/response and pickup radius/range are exposed on `Player`. Focus's slow
multiplier is still on `Player/Focus`.

One `ItemInstance` transfers between a single world RigidBody3D and an inventory
slot. Equipping creates only a visual model; collecting removes the world body.
Collision layers remain **1 Arena, 2 Player, 3 Objects, 4 Targets**. Damage, inventory,
targeting and feedback communicate through signals or the shared combat interface.

## Validate

Run from the repository directory:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 60 --script res://tests/milestone_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/combat_test.gd
```

The original regression suite covers spawning, falling, pickup, inventory,
state-preserving drops, occlusion, Focus movement/camera, health and scene reset.
The combat suite covers actual sleeping-body pushes, forgiving pickup, held-model
isolation, shooting/rate/ammo/reload, switching, Focus timing, melee, parry and real
projectile reflection, mass-dependent throws, speed-dependent impact damage,
bounce, stagger, repeat-hit prevention and recovery. Each suite has a timeout and
exits nonzero on failure. Fixed-FPS is a test-runner option, not a gameplay change.

Manual checks:

1. Let props settle; walk into balls, pistols, pans and chairs. Compare resistance.
2. Pick up a small ball while moving. Fill the inventory and try another pickup.
3. Equip each object against a wall; it should stay visible. Test blocked F/G,
   then throw into open space and recover the object.
4. Shoot the dummy five times, reload with R, and reset only the dummy with T.
5. Move close and test pistol-whip and pan swings. Test the visible parry window.
6. Charge/release a baseball at the dummy; compare with a short charge and toss.
7. Repeat with Focus, switch weapons during reload/charge, release/recapture the
   mouse, and use F5 to reset the entire test.

## Scope and limitations

Only pistol, frying pan and baseball have attacks. Chair and umbrella retain
pickup/equip/drop and generic physical throwing; their attacks and thrown impact
damage are deferred. Player health, enemies, waves, new levels, progression and
player shadows are not added. No elaborate animation or audio system is included.

The dummy's knockback/stagger is visual because it is intentionally stationary;
loose props receive actual impulses. The parry API and physical reflection are
verified in tests; regular play has no enemy attacks to parry. Generic throws are
instant, with physical spin; no delayed hand/windup animation was added. Conservative
release clearance may reject some tight spaces. Held models draw over walls by
design, but attacks and item release still obey world collisions.

Validated with Godot 4.6.3 on Linux, including a software-OpenGL Compatibility render.
Windows execution/export remains untested. For packaging, install matching export
templates and use **Project → Export → Windows Desktop**. The preset embeds project
data in `builds/windows/ObjectRain.exe`; templates are not needed to run in the editor.
