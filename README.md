# Object Rain — iteration 03

A Godot 4 first-person physics playground with ten falling props, five inventory
slots, physical throws, pistol/pan/baseball combat and toggle Focus.

## Run

Use **Godot 4.6.x Standard** (tested with **4.6.3**). Import `project.godot` and press
F5, or run `godot --path .` from this directory. No .NET, plugins, downloaded assets,
services or credentials are required.

Click the game to capture the mouse if necessary. Press Shift to toggle Focus.
F5 **inside the running game** resets the test arena; press Shift again afterward
if you want to slow the opening rain.

| Input | Action |
| --- | --- |
| WASD / mouse / Space | Move / look / jump |
| E | Instantly pick up the highlighted object |
| 1–5 / mouse wheel | Select slot, including empty slots |
| F | Physical throw of any equipped object |
| LMB | Pistol fire / pan swing / hold and release to throw baseball |
| RMB | Pistol-whip / pan parry / baseball underhand toss |
| R | Reload pistol |
| Shift | Toggle unlimited Focus |
| T | Reset dummy only |
| F5 | Reset arena, inventory, dummy and object rain |
| Escape / click | Release or capture mouse / recapture mouse |

**G/drop has been removed.** Use F to free a slot, then recover props with E.
Near walls or other objects the game finds a safe release position and allows the
throw to collide naturally. A genuinely unavailable release keeps the item equipped.

## Iteration 3 changes

- Focus eases over 0.18 real seconds to **15% world**, **75% movement** and
  **80% player-action** speed. Mouse look remains at 100%.
- Pistol: **4.5 shots/sec**, 20 damage, 12 rounds. Pan: **2 swings/sec**, 25 damage.
- Cooldowns, reload, charge, parry, equipped animations, a short equip interval and
  throw recovery use the same action clock. Released objects use ordinary world physics.
- Throw clearance uses the actual prop shape, can shorten release before an obstacle,
  and can use a nearby side/overhead position. Side throws converge on the camera aim.
- Stable arena, movement outside Focus, pickup assistance, inventory identity,
  physics pushing, baseball bounce/recovery and held-model rendering are retained.

For example, a 0.5-second action takes 0.625 real seconds in steady Focus; reloading
is about 1.1 seconds normally and 1.375 seconds in Focus. Projectiles remain much
slower than the player. There are no energy or duration restrictions.

## Developer reference

- [Current state, controls and tuning](docs/CURRENT_STATE.md)
- [Development history, iterations 1–3](docs/DEVELOPMENT_LOG.md)

Update both documents after every development iteration; `AGENTS.md` records this
standing requirement. Scene organization remains `scenes/arena.tscn`, `player.tscn`
and `dummy.tscn`; scripts live under `scripts/player`, `items`, `combat`, `components`,
`world` and `ui`, with shared weapon Resources in `resources/weapons`.

This iteration changes the Focus/controller timing, player release/input, combat
controller, held animation clock, world-item cooldown clock, pistol/pan data and
HUD. `scripts/items/release_placement.gd` is the new reusable clearance helper.
New tests cover iteration 3 behavior and differing render/physics frame rates.

## Validate

Run from this directory:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 60 --script res://tests/milestone_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/combat_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/iteration3_test.gd
godot --headless --path . --fixed-fps 30 --script res://tests/frame_clock_test.gd
godot --headless --path . --fixed-fps 144 --script res://tests/frame_clock_test.gd
```

Suites load the real arena and fail with nonzero status. Existing regression tests
are updated only where iteration 3 intentionally changes their expected behavior.
The new checks measure movement, firing/reload/swing/parry/charge/animation/switch/
throw intervals, physical obstacle impacts, spawn separation, impossible release,
identity, recovery, midair trajectories and rapid Focus toggles. The frame-rate
checks catch applying global slowdown twice or changing the clock mid-frame.

Manual playtest still needed for subjective feel and Windows:

1. Compare movement and rapid pistol/pan attacks with Focus toggled on/off.
2. Reload, charge a baseball, parry, switch slots and throw in both modes.
3. Throw toward a close wall, a chair directly ahead and the floor; recover props.
4. Fill all five slots, throw one, and collect a replacement. Try a very cramped corner.
5. Toggle Focus repeatedly while moving/firing and while a baseball is midair.
6. Release/recapture the mouse and reset the dummy/arena. Confirm the HUD controls.

## Limits and export

No new AI, levels, weapons, progression, Focus meter or simulated bullets. Chair and
umbrella remain throwable props. The stationary dummy's knockback is visual. Parry
is functional but there are no enemy attackers in regular play. The finite release
search can refuse unusual tight geometry without losing the item. No elaborate
throw animation or audio system is included.

Linux Godot 4.6.3 and software-OpenGL Compatibility rendering are validated. Windows
execution/export is not validated here. Install matching Godot export templates and
use **Project → Export → Windows Desktop** to create `builds/windows/ObjectRain.exe`.
