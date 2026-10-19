# Object Rain — iteration 04

A Godot 4 first-person physics playground built around **unique, situational object
interactions**, not a primary/secondary attack template for every object.

## Run

Import `project.godot` with **Godot 4.6.x Standard** (tested with 4.6.3), then press
F5; or run `godot --path .`. No plugins, .NET, external assets or services needed.
The test arena keeps ten falling props and five inventory slots. Thirty random
objects is the long-term game premise; this iteration preserves existing rain.

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
| F5 inside game | Reset arena, inventory, rain and launcher |
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

Try these in normal time and Focus:

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
godot --headless --path . --fixed-fps 30 --script res://tests/frame_clock_test.gd
godot --headless --path . --fixed-fps 144 --script res://tests/frame_clock_test.gd
```

The full suite passes 328 checks. Tests use the real arena; failed assertions return
nonzero status. Coverage includes action
clocks, inventory identity, safe release, physical impacts, shield directions,
reflection into targets, thin-wall CCD/sweep safety, ownership and cleanup.

## Developer reference and limits

- [Current state, architecture, tuning and controls](docs/CURRENT_STATE.md)
- [Development history and decisions](docs/DEVELOPMENT_LOG.md)

Capabilities live in weapon Resources; small behavior nodes supply optional
object-specific actions. ProjectileDefinition configures reusable physical attacks.
The default projectile is 12 m/s, 10 damage, with an eight-world-second lifetime.
Launcher interval, limits and projectile data are editable in the Inspector.
Both development documents must be updated each iteration; completed changes are
committed and pushed, as recorded in AGENTS.md.

No AI, progression, new levels/types, Focus meter, umbrella gliding or simulated
pistol bullets. The dummy stays upright while sliding; the player has test counters
instead of a death loop. Shield protection uses an angle check, not mesh collisions.
The launcher model is decorative. Extremely cramped releases can fail while keeping
the item. Visuals are placeholders, with no audio system or detailed hands.

Linux Godot 4.6.3 and software-OpenGL Compatibility rendering are validated. Windows
execution/export and subjective feel require manual playtests. For a Windows build,
install matching Godot export templates, then use Project → Export → Windows Desktop.
