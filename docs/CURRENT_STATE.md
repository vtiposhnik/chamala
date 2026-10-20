# Object Rain — current state after iteration 5

## Philosophy and working gameplay

**Object Rain focuses on unique, situational object interactions rather than giving
every object conventional weapon attacks.** The long-term premise is choosing five
objects from a rain of 30 random objects. This test arena retains its playtested ten
props (two of each kind). The design now also explores a broader first-person
physics-action adventure. Iteration 5 adds a contained traversal experiment while
preserving the original arena and its object-rain/combat systems.

- Godot 4.x GDScript, Compatibility renderer; validated with Godot 4.6.3 on Linux.
- Original enclosed arena plus a separate normal/low/zero-gravity traversal greybox.
- Existing FPS movement/look, five inventory slots, number/wheel
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
| WASD / mouse / Space | Move / look / jump; in gravity anomalies, camera-relative steering / surface push-off |
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
| Backspace | Traversal only: return to checkpoint, keeping inventory |
| F5 (in game) | Reset current scene, inventory and props |
| F6 | Switch between arena and traversal, starting the selected scene fresh |
| Escape / click | Release/capture mouse |

Launcher positions remain fixed after K; subsequent shots aim at the current player
position. Stations clamp inside arena walls and try nearby clear muzzle positions.
An obstructed muzzle cannot fire; shots still collide with intervening props.
Releasing the mouse or losing application focus cancels blocking/charge/parry and
eases out of Focus. Simulation continues. Scene removal resets global time.

## Traversal experiment

Open `scenes/traversal.tscn`, or press F6 from the default arena. The scene has a
normal starting platform with five comparison props; an enclosed 18 m corridor
with obstacles, 18% gravity and a nested zero-G pocket; and a ten-metre broken
bridge with a 12% gravity field. Thirteen props use the existing five definitions.
The destination has a backstop for overshoots. No new object type is introduced.

In anomalies, airborne velocity persists with light damping. WASD accelerates
relative to camera aim, including pitch, so looking up/down provides modest 3D
steering. A finite steering reserve prevents indefinite airborne thrust. Space
pushes away from a nearby solid surface or prop of at least 3 kg; it cannot jump
again in empty space. Landing or a successful push restores the steering reserve.
Grounded movement/jumps keep the existing controls. After leaving a zone in the
air, inertia continues until landing; ordinary jumps begun outside zones retain
normal FPS movement. Coasting collisions transfer bounded impulses to props.

| Traversal parameter | Default / location |
| --- | --- |
| Air acceleration / damping | 2.5 m/s² / 0.03 s⁻¹, Player/Traversal |
| Maximum controlled speed | 6 m/s along steering direction; faster external momentum is preserved |
| Steering reserve | 4 m/s of accumulated velocity change per landing/push-off |
| Push speed / outward cap / cooldown | +5 m/s / 8 m/s / 0.35 movement seconds |
| Surface reach | 0.65 m from body center horizontally; 1.05 m vertically |
| Minimum pushable mass / reaction | 3 kg / 12 N·s, reaction capped to 3 m/s object delta-v |
| Throw velocity inheritance | 65% of stored movement velocity while traversing |
| Corridor / pocket / bridge gravity | 0.18 / 0.00 / 0.12, respective Area3D nodes |
| Field boundary widths | 1 m corridor/bridge; 0.6 m zero-G pocket |
| Field rigid-body damping | 0.02 s⁻¹, capped to never increase the body's existing damping |
| Fall rescue height | −10 m, TraversalLab |

`GravityZone` uses an Area3D box for body enrollment and samples a smooth spatial
boundary at each body's collider center. Higher-priority zones blend over lower
ones, including nested zero-G pockets. Native Area gravity overrides are disabled;
`GravityResponse` adjusts each rigid body's original gravity scale and damping,
restoring them outside fields without changing its velocity. Bodies are enrolled
on overlap; a newly entering body can take a physics tick to receive its response.
Gravity-free projectiles retain their original zero gravity. Gravity acceleration
has a vector API, but all implemented fields point down. Zones should remain static
for this experiment; no directional gravity or surface reorientation is included.

Player field sampling and inertia use the existing movement clock. Prop gravity,
damping and impulses remain on the world clock. Throws inherit stored movement
velocity, never the inflated velocity used internally to compensate for Focus.
The HUD reports effective real-time player velocity, gravity multiplier, remaining
steering reserve and checkpoint stage. All movement/field values are Inspector exposed.

Landing at bridge departure and destination sets checkpoints. Falling or Backspace
restores position, clears movement/held actions and exits Focus, retaining inventory.
Fallen preplaced props return to their original comparison positions, keeping the
gap populated during longer tests; thrown props return above the checkpoint. Both
retain item identity and receive harmless reset motion. F5 fully resets the experiment. F6 discards the current scene and
loads a fresh arena/traversal scene; inventory is not carried between the two labs.

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

- No enemy AI, waves, progression, production levels/new object types, Focus energy,
  umbrella gliding, grappling, sideways gravity, ceiling walking, selective freezing,
  consumables, player death loop, or simulated pistol bullets.
- The launcher is a test fixture with visual-only geometry; K may put it behind a
  prop. Real collisions then intercept its shots. A blocked muzzle waits for a clear
  position instead of spawning inside a target. L/J/K work while mouse is released.
- Release search is bounded; unusually cramped geometry can refuse a throw while
  retaining the item. Contact solver tolerance and tick-quantized action times remain.
- Damageable dummies slide upright, rather than tumble. Placeholder art, no sound
  system or elaborate hands/animations. Shield coverage is angular, not per-triangle.
- Traversal is a small feel experiment. Steering is finite; exhausted players need
  a surface or a checkpoint restart. Push-off uses short rays, not a grab/climb system.
  Gravity affects the player and rigid props/projectiles; the arena-only dummy
  CharacterBody controller is unchanged. Greybox signs/platforms are placeholders.
- Thirty simultaneous test projectiles have cleanup coverage; this is not a target
  hardware performance benchmark. Windows export and subjective feel need playtests.

See README for test commands and manual scenarios. Continue updating this file and
DEVELOPMENT_LOG.md after every iteration; commit and push completed changes.
