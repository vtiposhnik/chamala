# Object Rain — current state after iteration 4

## Philosophy and working gameplay

**Object Rain focuses on unique, situational object interactions rather than giving
every object conventional weapon attacks.** The long-term premise is choosing five
objects from a rain of 30 random objects. This test arena retains its playtested ten
props (two of each kind); iteration 4 changes interactions, not rain distribution.

- Godot 4.x GDScript, Compatibility renderer; validated with Godot 4.6.3 on Linux.
- Original enclosed arena, FPS movement/look, five inventory slots, number/wheel
  selection and forgiving instant pickup. Props retain mass-dependent pushing.
- Physical throws use validated release shapes, owner separation and normal world
  collisions. Item identity/ammo persist through recovery. G/drop remains removed.
- Held models use an isolated depth pass and remain visible beside walls.
- Unlimited toggle Focus; world, movement and actions use separate effective clocks.
- Three 100-HP test dummies have damage flashes, numbers, physical sliding knockback,
  stagger and reset. They stay upright; there is no ragdoll or AI.
- Optional launcher provides visible incoming projectiles. Player test damage,
  hit count, block count and launcher outcomes appear in the HUD. No death/lives loop.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse / Space | Move / look / jump |
| E | Pick up highlighted object |
| 1–5 / mouse wheel | Select slot |
| F | Throw any held object, including a powerful chair throw |
| LMB | Pistol fire; pan swing/deflect; charge/release baseball; chair throw; hold umbrella open |
| RMB | Pistol-whip; timed pan parry; baseball underhand toss; unavailable on chair/umbrella |
| R | Reload pistol only |
| Shift press | Toggle Focus; key repeat/release do not toggle |
| L | Toggle automatic test launcher (initially OFF) |
| J | Fire one launcher shot, including while automatic mode is off |
| K | Move launcher to front, side, rear of the player's current facing, cycling |
| T | Restore all dummy health/positions and clear player test damage/block counters |
| F5 (in game) | Reset arena, inventory, rain, launcher and counters |
| Escape / click | Release/capture mouse |

Launcher positions remain fixed after K; subsequent shots aim at the current player
position. Stations clamp inside arena walls and try nearby clear muzzle positions.
An obstructed muzzle cannot fire; shots still collide with intervening props.
Releasing the mouse or losing application focus cancels blocking/charge/parry and
eases out of Focus. Simulation continues. Scene removal resets global time.

## Objects and capabilities

| Object | Behavior and capabilities | Values |
| --- | --- | --- |
| Pistol | Shootable, reloadable, throwable, recoverable; hitscan and whip | 20 damage, 4.5 shots/s, 12 rounds, 1.1 s reload; whip 12 damage / 0.5 s recovery |
| Pan | Deflecting, throwable, recoverable; swing retains melee and opens defense window | 25 melee damage, 2 swings/s, 0.25 s window, 110° frontal parry; thrown damage up to 25 at 7 m/s |
| Baseball | Bouncing, throwable, recoverable; charge, toss, speed-based impact | 1 s charge; up to 30 damage; full launch 24 m/s; minimum damaging speed 2 m/s |
| Chair | Heavy/two-handed, throwable, recoverable; low central hold, no melee | 6 kg; 60 N·s throw impulse, 10 m/s cap; up to 60 damage at 10 m/s; knockback impulse 24 |
| Umbrella | Defensive, throwable, recoverable; hold to open, no melee | 0.12 action-second opening, 120° frontal protection, Standard category only |

Definitions under `resources/weapons/` expose capability flags, physical properties,
throw/impact damage and action tuning. Existing small behavior nodes handle optional
actions; unused actions do nothing and contextual hints omit them. No universal
ability framework or unused consumable/gliding implementation has been added.

Umbrella protection begins when fully open, ends immediately on release and is
canceled on switch/throw/unequip. Its canopy visibly opens/closes on action time.
Defense checks approach direction at player contact; the decorative mesh itself
is not a solid shield collider. Standard launcher shots are consumed on block;
recoverable standard thrown objects stop and fall. Heavy chairs cannot be blocked
by the default umbrella or deflected by the pan. Categories are configurable.

Pan LMB swing and RMB parry share the existing 0.25-second window/cooldown. A success
consumes the window, flashes the model/HUD, and redirects a compatible projectile
along camera aim. Ownership changes and a temporary collision exception prevents
immediate self-hits. Deflected shots can damage dummies. Chair, pan and baseball
physical impacts damage each target at most once per launch. Sleeping disarms them.
The pan retains zero scripted throw spin to avoid thin-box rocking; contact rotation
remains physical. Chair and baseball retain ordinary tumbling/bouncing.

## Timing and projectile configuration

| Parameter | Value / location |
| --- | --- |
| Focus world / movement / actions / look | 0.15 / 0.75 / 0.80 / 1.00, `Player/Focus` |
| Focus transition | 0.18 real seconds |
| Move speed | 5.5 m/s normal, 4.125 in steady Focus |
| Equip / throw recovery | 0.10 / 0.22 action seconds, Combat / weapon Resource |
| Pickup / release / aim reach | 3.4 / 1.5 / 50 m, Player |
| Release margin / assisted pickup radius | 0.02 / 0.24 m |
| Player push force / response | 65 / 18, unchanged |
| Launcher interval / live-projectile cap | 1.5 world seconds / 64, Launcher node |
| Test projectile | 12 m/s, 10 damage, impulse 3, radius 0.09 m, mass 0.1 kg |
| Projectile lifetime / gravity / mask | 8 world seconds / 0 / arena + player + objects + targets |
| Projectile category / reflection speed | Standard / 1× incoming speed |
| Dummy mass equivalent / ground drag | 8 / 10, dummy Inspector |

The Focus controller remains the only time-scale writer. It changes global scale
late in `_process` (priority 10000), after consumers. Action/movement consumers
convert scaled delta to real time once, then apply their effective multiplier.
Durations above are action seconds: divide by 0.8 for steady-Focus real duration.
The shield opens in about 0.15 real seconds in Focus; pan window lasts 0.3125.
Physical velocities/impulses are never rescaled when toggling Focus.

`PhysicalProjectile` is a RigidBody3D with CCD and a swept sphere collision guard.
It uses `ProjectileDefinition` for speed, damage, mass, radius, gravity, lifetime,
collision mask, category and reflection eligibility. The projectile stores its own
source, temporary owner and terminal state. Blocks/impacts/expiry clean it up once;
reflection continues flight. Launcher shots use zero damping; props keep existing
friction/damping. Layer 5 is reserved for projectiles. The pistol remains hitscan.

## Limits and future work

- No enemy AI, waves, progression, new environments/object types, Focus energy,
  umbrella gliding, consumables, player death loop, or simulated pistol bullets.
- The launcher is a test fixture with visual-only geometry; K may put it behind a
  prop. Real collisions then intercept its shots. A blocked muzzle waits for a clear
  position instead of spawning inside a target. L/J/K work while mouse is released.
- Release search is bounded; unusually cramped geometry can refuse a throw while
  retaining the item. Contact solver tolerance and tick-quantized action times remain.
- Damageable dummies slide upright, rather than tumble. Placeholder art, no sound
  system or elaborate hands/animations. Shield coverage is angular, not per-triangle.
- Thirty simultaneous test projectiles have cleanup coverage; this is not a target
  hardware performance benchmark. Windows export and subjective feel need playtests.

See README for test commands and manual scenarios. Continue updating this file and
DEVELOPMENT_LOG.md after every iteration; commit and push completed changes.
