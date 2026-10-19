# Object Rain — current state after iteration 3

## Working gameplay

- Godot 4.x GDScript, Compatibility renderer; validated with Godot 4.6.3 on Linux.
- Original enclosed arena, ten falling props (two of each kind), FPS movement/look,
  five inventory slots, number/wheel selection and instant forgiving pickup.
- Physics props sleep normally and can be pushed with mass/friction-dependent resistance.
- F throws the selected object. Release is validated separately from its flight path;
  nearby obstacles receive physical collisions. Item identity and ammo survive recovery.
- Held models render in a separate transparent depth pass and remain visible near walls.
- Toggle Focus has no meter, duration limit or cost. Camera look is unchanged.
- Stationary 100-HP dummy with damage flash, hit numbers, visual stagger and reset.
- HUD: inventory, ammo/reload, charge/parry, hit confirmation, target mass/speed and Focus.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse / Space | Move / look / jump |
| E | Pick up highlighted object |
| 1–5 / mouse wheel | Select slot |
| F | Throw selected object; no separate Drop binding |
| LMB | Fire pistol / swing pan / hold then release to throw baseball |
| RMB | Pistol-whip / timed pan parry / underhand baseball toss |
| R | Reload pistol |
| Shift press | Toggle Focus on/off; key repeat and release do not toggle |
| T | Reset dummy only |
| F5 (in game) | Reset arena, inventory, dummy and rain |
| Escape / click | Release or capture mouse / recapture mouse |

Releasing the mouse or losing application focus cancels active input and eases out
of Focus; simulation continues. Scene removal resets global time immediately.

## Configuration

| Parameter | Normal | Focus target | Location |
| --- | --- | --- | --- |
| World physics speed | 1.00 | 0.15 | `Player/Focus.world_multiplier` |
| Movement speed multiplier | 1.00 | 0.75 | `Player/Focus.movement_multiplier` |
| Player action speed | 1.00 | 0.80 | `Player/Focus.action_multiplier` |
| Camera input speed | 1.00 | 1.00 | Unscaled relative mouse input |
| Time transition | — | 0.18 real seconds | `Player/Focus.transition_seconds` |
| Move speed | 5.5 m/s | 4.125 m/s at steady input | `Player.move_speed` |
| Equip interval | 0.10 s | 0.125 real s | `Player/Combat.switch_seconds` |
| Throw recovery | 0.22 s | 0.275 real s | Weapon `throw_recovery` |
| Pickup | 3.4 m range, 0.24 m assist radius | Same | `Player` |
| Release search | 1.5 m reach, 0.02 m margin | Same | `Player` |
| Throw aim convergence | Up to 50 m | Same | `Player.throw_aim_distance` |
| Push force / response | 65 / 18 | World-delta force integration | `Player` |

The Focus controller is the sole global time-scale writer. Movement and action
consumers divide the scaled delta by the current world scale **once**, then apply
their own effective multiplier. Global scale changes happen after frame consumers
(`process_priority = 10000`); keep timing consumers before this controller.
`set_active(bool)` is independent of the toggle input policy and can support a
future hold option. Only gameplay state, not raw projectile velocity, changes when
Focus is toggled. HUD messages use real seconds; dummy feedback uses world seconds.

## Weapons

| Weapon | Implemented behavior | Current values |
| --- | --- | --- |
| Pistol | Hitscan, physical hit impulse, recoil/flash, reload, whip | 20 damage, 4.5 shots/sec, 12 rounds; 1.1 s reload; whip 12 damage / 0.5 s recovery |
| Frying pan | Arc/LOS melee, knockback, frontal timed parry and reflection interface | 25 damage, 2 swings/sec, 0.25 s parry window |
| Baseball | Charged rigid-body throw, underhand toss, bounce, speed-based damage, stagger, recovery | 1.0 s charge; up to 30 damage; full launch 24 m/s; 2 m/s minimum damaging impact |
| Chair / umbrella | Pickup, equip and generic physical throw | No primary/secondary combat or thrown damage |

Durations above are **action seconds**. In steady Focus divide a duration by 0.8
(reload 1.375 s, pan interval 0.625 s, parry 0.3125 s, charge 1.25 s). Pistol's
nominal real firing rate is 3.6/sec in Focus. Event timing has tick-sized rounding;
sustained attacks retain fractional cadence without firing catch-up bursts.

Definitions in `resources/weapons/` expose damage, rate, mass, friction, bounce,
reload, parry, charge and throw tuning. Ammo and cooldown persist on `ItemInstance`.
The pan's scripted launch spin is zero to avoid thin-box rocking after wall impacts;
collisions can still rotate it normally. Other props retain their configured spin.
Switching cancels partial reload/charge/parry; a global throw recovery prevents
switching from bypassing release pacing. Reserve pistol ammo is unlimited for testing.
After release, all prop motion, gravity, collisions, owner grace and bounce use world
time; launch impulses are never scaled by Focus. No environment collisions are disabled.

## Unimplemented and known limits

- No Grunt/Scavenger/Brute AI, enemy waves, player health, progression, new rooms,
  simulated pistol bullets, Focus energy system, chair/umbrella attacks or player shadows.
- Parry callbacks/physical reflection work and are automated-tested; there are no
  enemies attacking in normal play. Dummy knockback is intentionally a visual wobble.
- Release search is bounded to nearby forward/side/overhead positions. It may decline
  unusual tight geometry; failure keeps inventory unchanged. It never searches for a
  distant release point. Held models draw over walls, but attacks obey world collisions.
- Throw release is instant; there is no elaborate hand/windup animation. Placeholder
  visuals remain, with no audio system. Minor collision contact tolerance is expected.
- Windows execution/export and subjective pacing require a human playtest. Matching
  export templates are required only for packaging, not editor play.

See `README.md` for automated test commands. Update this file and
`DEVELOPMENT_LOG.md` at the end of every future development iteration.
