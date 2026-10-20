# Object Rain — iteration 05

A Godot 4 first-person physics playground built around **unique, situational object
interactions** and an experimental first-person physics-action adventure direction.

## Run

Import `project.godot` with **Godot 4.6.x Standard** (tested with 4.6.3), then press
F5; or run `godot --path .`. No plugins, .NET, external assets or services needed.
The original arena remains the default. Press **F6** for the new traversal experiment,
or open `scenes/traversal.tscn` directly. The arena keeps ten falling props and five
inventory slots. Thirty random objects is the long-term game premise; existing rain
is preserved.

## Iteration 5: traversal experiment

A normal starting platform leads into an enclosed low-gravity corridor, a zero-G
pocket and a broken bridge. Existing objects drift, collide, bounce and retain their
mass-dependent impulse responses. Throws inherit some player movement momentum.

- **Look + WASD:** steer in three dimensions while airborne, with inertia and a
  limited steering reserve. Landing or pushing off replenishes the reserve.
- **Space:** jump from the floor or push off a nearby surface/heavy prop. There are
  no free-space jumps. Look toward a surface and get close to push away from it.
- **Shift:** existing Focus (15% world / 75% movement / 80% actions / 100% look).
- **Backspace:** return to the latest checkpoint, retaining inventory. Falling also
  respawns the player; fallen objects are rescued with the same identity.
- **F5:** reset the whole current experiment. **F6:** switch labs; the selected lab
  starts fresh, including its inventory.

Run forward and jump near the bridge edge to cross. The destination's backstop
catches overshoots. The HUD shows velocity, gravity, steering reserve and checkpoint.
Air acceleration, damping, controlled speed, push strength, throw inheritance and
field strengths/boundaries are exposed in the Inspector. See the configuration table
in [CURRENT_STATE.md](docs/CURRENT_STATE.md).

## Controls and objects

| Input | Action |
| --- | --- |
| WASD / mouse / Space | Move / look / jump |
| E / 1–5 or wheel | Pick up / select slot |
| F | Throw any held object; recover it with E |
| Shift | Toggle unlimited Focus |
| LMB — chair | Commit the heavy, two-handed chair to a powerful throw |
| LMB — umbrella | Hold to open frontal shield; release to close |
| LMB / RMB — pan | Swing with timed deflection / timed parry |
| LMB / RMB / R — pistol | Hitscan fire / whip / reload |
| Hold-release LMB / RMB — baseball | Charge and throw / underhand toss |
| L / J / K | Toggle launcher / single shot / place front, side, rear |
| T | Restore all three dummies and clear player test damage/block counters |
| Backspace | Traversal checkpoint restart, keeping inventory |
| F5 inside game | Reset current scene and inventory |
| F6 | Switch arena / traversal, with a fresh scene |
| Escape / click | Release/capture mouse |

Chair and umbrella have no secondary attack. Contextual hints show supported actions.
There is no G/drop binding. The launcher starts disabled, remains stationary until
K, and aims each shot at the player. Props can intercept its shots.

- **Chair:** 6 kg, 60 N·s launch, 10 m/s cap; up to 60 direct-impact damage plus
  physical knockback. It tumbles, stays in the world, and retains identity on recovery.
- **Umbrella:** visibly opens in 0.12 action seconds; blocks Standard projectiles
  across 120° in front. Sides, rear and Heavy impacts remain dangerous. Release,
  switching and throwing cancel protection. No melee, reflection or parachute yet.
- **Pan:** existing 25-damage, 2/s swing also opens a 0.25-second deflection window.
  Successful contact redirects eligible projectiles toward aim with a flash/HUD
  cue and temporary self-collision immunity. Physical throws also damage targets.
- **Pistol/baseball:** existing hitscan, reload, charge, bounce and recovery remain.
- **Focus:** unchanged 15% world, 75% movement, 80% actions, 100% look, 0.18-real-second
  transition. Released objects and launcher shots follow ordinary world-time physics.

## Testing

Traversal playtest:

1. Press F6. Compare normal walking/jumping on the start platform with movement in
   the corridor. Release WASD in the air; momentum should persist.
2. Jump in the zero-G pocket, look up/down and steer gently. Near a wall, ceiling
   or chair, press Space to push off. Try the same in open space and beside a baseball.
3. Pick up and throw objects while drifting. Recover them; compare chair/baseball
   motion. Toggle Focus while airborne and while objects cross field boundaries.
4. Reach the bridge checkpoint. Run and jump toward the marked destination. Repeat
   in Focus; try entering/exiting Focus mid-flight. Backspace retries the crossing.
5. Fall deliberately, throw a prop into the gap, and confirm respawn/recovery.
   F5 resets everything. F6 returns to the original arena and its testing tools.

Arena regression playtest, in normal time and Focus:

1. Collect a chair, aim at the three dummies and LMB throw. Observe damage and
   sliding knockback; recover the same chair. T restores dummy positions/health.
2. Hold an umbrella open, press K to put the launcher ahead, then J for one shot.
   Check BLOCK feedback. K cycles to side/rear; those hits increase TEST DAMAGE.
3. Equip the pan, use J and time a swing or RMB parry just before impact. Aim a
   reflected shot at a dummy. Use Focus to see the approach more clearly.
4. Press L for repeated shots. Switch or throw the umbrella while open, release
   the mouse, and try late pan swings. Successful defenses prevent test damage.
5. Throw near walls/props, fill all five slots, recover thrown objects, reload the
   pistol, bounce a baseball, and toggle Focus while projectiles/chairs are midair.

Run the full suite with `bash tests/run_tests.sh` (Bash, ripgrep and Godot). The
runner also rejects Godot script errors that would otherwise return exit code zero.
Individual checks from this directory:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 60 --script res://tests/milestone_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/combat_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/iteration3_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/iteration4_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/iteration5_test.gd
godot --headless --path . --fixed-fps 30 --script res://tests/frame_clock_test.gd
godot --headless --path . --fixed-fps 144 --script res://tests/frame_clock_test.gd
```

The full suite passes 385 checks. Tests use the real scenes; failed assertions return
nonzero status. Coverage includes action clocks, inventory identity, safe release, physical impacts, shield directions,
reflection into targets, thin-wall CCD/sweep safety, ownership and cleanup. New
traversal checks cover nested fields, zero/near-zero gravity, rigid momentum and mass,
3D steering limits, surface/prop push-off, Focus, inherited throws, checkpoints and
actual bridge crossings in normal time and Focus.

## Developer reference and limits

- [Current state, architecture, tuning and controls](docs/CURRENT_STATE.md)
- [Development history and decisions](docs/DEVELOPMENT_LOG.md)

Capabilities live in weapon Resources; small behavior nodes supply optional
object-specific actions. ProjectileDefinition configures reusable physical attacks.
The default projectile is 12 m/s, 10 damage, with an eight-world-second lifetime.
Launcher interval, limits and projectile data are editable in the Inspector.
Both development documents must be updated each iteration; completed changes are
committed and pushed, as recorded in AGENTS.md.

No AI, progression, production levels/new object types, Focus meter, umbrella gliding
or simulated pistol bullets. Traversal uses static downward gravity fields, finite steering and
short push-off rays; no grappling, climbing, gravity reversal or selective freezing.
Its feel and tuning are experimental. The dummy stays upright while sliding; the
player has test counters instead of a death loop. Shield protection uses an angle check, not mesh collisions.
The launcher model is decorative. Extremely cramped releases can fail while keeping
the item. Visuals are placeholders, with no audio system or detailed hands.

Linux Godot 4.6.3 and software-OpenGL Compatibility rendering are validated. Windows
execution/export and subjective feel require manual playtests. For a Windows build,
install matching Godot export templates, then use Project → Export → Windows Desktop.
