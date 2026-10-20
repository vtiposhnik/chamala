# Object Rain — development log

Update this file and `CURRENT_STATE.md` at the end of every future development
iteration. Retrospectives below are based on the repository and the supplied
playtest briefs; suggested next steps are not authorization to implement them.

## Iteration 1 — First playable foundation

- **Objective:** establish the FPS physics interaction loop in a small arena.
- **Implemented:** enclosed test arena, first-person movement/look, ten falling
  primitive props, five-slot inventory, highlighting/pickup, equipping/dropping,
  hold-to-Focus and a stationary dummy with Health. Five Resource definitions and
  separate world/equipped representations provided the weapon foundation.
- **Decisions:** Compatibility rendering, built-in rigid-body physics, one persistent
  item identity across inventory/world transfers, collision layers and signals.
- **Fixed/guarded:** duplicate pickup, full/empty inventory, unsafe drop positions,
  floor tunneling and time-scale reset on scene removal.
- **Limitations then:** attacks and AI inactive; held models were hidden near walls;
  conservative drop clearance; 10% world time with unscaled movement/camera.
- **Next step then:** refine interactions and implement the first weapons.
- **Reference:** commit `730d993`, `scenes/`, `scripts/items/`, `tests/milestone_test.gd`.

## Iteration 2 — Physics refinement and first playable combat

- **Objective:** improve physical interactions and enable pistol, pan and baseball.
- **Implemented:** mass-dependent contact pushing; physical throwing with owner
  separation; forgiving pickup query with line of sight; isolated held-model
  rendering; pistol hitscan/reload/whip, pan swing/parry and charged baseball/toss;
  hit feedback, ammo, mass/speed display and dummy damage/stagger/reset.
- **Decisions:** share hit application and weapon behavior interfaces; keep ammo and
  cooldown on item instances; apply launch impulses after physics mass synchronization;
  use short velocity history for CCD impact damage and one hit per target per launch.
- **Bugs fixed:** immovable sleeping props, stepping over thin pans without pushing,
  incorrect launch speeds from unsynchronized mass, wall-triggered held-model hiding,
  overwritten reflection velocity, and unreliable damage from CCD-clamped speed.
- **Limitations then:** all weapon actions followed the 10% world clock in Focus;
  blocked release sweeps rejected some valid throws; separate G/drop remained.
  Pistol rate was 3/sec and pan rate 1.6/sec. No enemies or player health.
- **Next step then:** playtest pacing, Focus action timing and obstacle clearance.
- **Reference:** commit `ea378f1`, `scripts/combat/`, `tests/combat_test.gd`.

## Iteration 3 — Combat pacing, Focus and throwing refinement

- **Objective:** preserve the tested systems while separating player/world timing,
  increasing attack responsiveness and allowing physical throws near obstacles.
- **Implemented:** Shift toggles unlimited Focus; smooth 0.18-real-second transition;
  effective Focus speeds of 0.15 world, 0.75 movement, 0.80 actions and 1.00 look.
  Pistol is 4.5 shots/sec; pan is 2 swings/sec; damage and magazines are unchanged.
  Actions, animations, short equip delay and throw recovery share the action clock.
  F is the inventory release control; the G binding and drop hints/API are removed.
- **Decisions:** `FocusController` converts scaled delta to real time once. It applies
  the next global scale late in `_process`, after gameplay consumers, because Godot
  snapshots time scale per frame. Fractional automatic-fire tick time is retained
  without idle-time accumulation or catch-up bursts. Projectiles retain ordinary
  world-space velocities, collision masks and physics after release.
- **Throw fix:** `ReleasePlacement` uses the real collision shape. It stops before
  an obstacle, validates a spawn clear of the player, and can try bounded side or
  overhead positions. Clear-path/line-of-sight checks prevent placing through an
  obstruction. Side launches converge toward the camera aim point. Flight is allowed
  to collide immediately; an impossible release retains the equipped item.
- **Other fixes:** same-slot selection no longer restarts the held pose; cooldowns
  survive switching/recovery; full-inventory hints now direct the player to throw.
  Close-wall tests exposed persistent thin-pan rocking into the floor: the pan's
  optional scripted launch spin is now zero. Collision-generated rotation, sleeping,
  contact pushing and the other props' spin remain unchanged.
- **Validation:** Godot headless import, retained foundation/combat regressions,
  measured movement and weapon cadence, Focus parry/charge/reload/animation/switch/
  recovery timing, wall throws for all five props, nearby-chair impact, floor
  clearance, full inventory, impossible release, projectile flight and rapid toggles.
  All 252 automated checks pass across the foundation, combat, iteration 3 and
  clock suites. Separate clock checks exercise 30 and 144 simulated render FPS. Compatibility
  rendering is checked on Linux software OpenGL; human feel and Windows need playtests.
- **Known limitations:** finite local release search can decline unusual cramped
  geometry; contacts have normal solver tolerance; action events are quantized to
  physics ticks. Throw release remains immediate, with a short action recovery.
  The dummy's stagger is visual and regular play has no enemy attacks to parry.
- **Suggested next steps:** collect feedback on 75% movement/80% action speeds and
  close-range throwing on Windows; tune exposed values before choosing another phase.
  No new enemies, levels, weapons, progression or Focus meter were added.

## Iteration 4 — Unique objects, projectile interactions and combat testing

- **Objective/philosophy:** Object Rain focuses on unique, situational object
  interactions rather than giving every object conventional weapon attacks. Keep
  the five-item prototype and stable Focus/pistol/baseball systems; add no AI or levels.
- **Implemented:** chair's low two-handed pose and powerful, recoverable throw;
  umbrella hold/open frontal defense; pan swing deflection alongside existing
  melee/parry, plus thrown pan damage; visible physical projectiles and an optional
  stationary launcher; three damageable dummies with physical upright knockback.
- **Controls/tuning:** LMB throws chair, holds umbrella, or swings/deflects pan. F
  throws all items. L toggles launcher, J single-fires, K cycles front/side/rear
  placement, T restores all dummies and player test counters. Chair 6 kg / 60 N·s /
  10 m/s / up to 60 damage; umbrella 120° and 0.12 action-second startup; pan retains
  0.25-second window. Launcher defaults to 12 m/s, 10 damage, 1.5-world-second interval.
- **Architecture:** lightweight Resource capability flags extend existing behavior
  nodes. Actions remain optional. ProjectileDefinition configures disposable shots;
  PhysicalProjectile stores source/owner/impact state. Standard/Heavy categories
  control blocking; reflection eligibility is separate. Existing WorldItem launch,
  safe release, persistent identity and impact history are reused for thrown damage.
- **Decisions:** defense is checked against incoming direction at player contact.
  Umbrella blocks without reflection; heavy chair impacts bypass it. Pan reflection
  follows aim and grants temporary owner separation. Rigid projectile CCD is backed
  by a sphere sweep to catch fast/thin contacts before damage. A terminal guard
  prevents duplicate hits. Dummies use collision-aware CharacterBody motion, not
  ragdolls. Player damage is a resettable test counter, not a death system.
- **Fixes:** launcher projectiles explicitly replace default Godot damping so their
  configured speed stays constant; ordinary props retain their existing damping.
  Shield protection ends immediately on release, even while the canopy closes.
  Visual testing caught a launcher station inside a dummy: stations now search for
  a clear muzzle, and blocked muzzles cannot fire. A shell test runner rejects script
  errors even when Godot returns zero, preventing false-positive suite results.
  Switching/throwing/mouse release clear shield state. Context hints omit unavailable
  attacks. Existing ten-object rain stays unchanged; 30 random objects is the longer-
  term game premise rather than a distribution change in this interaction iteration.
- **Files:** new chair/umbrella behaviors, projectile definition/body, launcher,
  `resources/test_projectile.tres`, `tests/iteration4_test.gd` and `tests/run_tests.sh`; updated weapon
  Resources, behavior/controller, item visuals/world impacts, player/HUD, dummy and
  arena scenes/scripts, controls, README and both development documents.
- **Validation:** 328 checks pass: 85 foundation, 73 combat, 88 iteration 3,
  76 iteration 4, and 3 each at 30/144 FPS. Together, the suites cover
  actual chair damage/knockback/recovery, frontal/side/rear/angle-boundary blocks,
  heavy-chair bypass, shield cancellation and Focus startup, real pan reflection
  into a dummy, late/nondeflectable hits, thrown pan damage, 300 m/s shots against
  a 2 cm wall, initial overlap, lifetime cleanup and 30 simultaneous projectiles.
  Clock checks cover 30/144 render FPS. Linux Compatibility visual checks cover
  chair pose, closed/open umbrella, launcher, Focus and HUD. Windows/feel need manual play.
- **Known limits:** angular shield coverage, decorative launcher collider omitted,
  bounded throw release search, upright sliding dummies, placeholder art/no audio.
  Launcher positions can be obstructed by props, which correctly intercept shots.
- **Suggested next steps:** playtest chair weight, umbrella view coverage and pan
  timing; tune the exposed values before choosing another development phase.
  No umbrella gliding, new types, enemies, progression or arenas were implemented.

## Iteration 5 — Low-gravity traversal and momentum experiment

- **Objective/design update:** explore a broader first-person physics-action
  adventure through a contained movement experiment. Preserve the original arena,
  object rain, five-slot inventory, object-specific behaviors and Focus tuning.
- **Implemented:** reusable box gravity zones with low, near-zero and zero strength;
  smooth spatial boundaries and prioritized overlaps; player momentum, limited
  camera-relative 3D steering, surface/heavy-prop push-off and inherited throw motion.
  A separate greybox contains a normal start, enclosed low-G corridor/zero-G pocket,
  ten-metre broken bridge and visible destination. Checkpoints, fall recovery and
  debug velocity/gravity/steering information make repeated experiments practical.
- **Architecture:** Area3D enrolls rigid bodies into GravityResponse, which samples
  the shared field and restores original gravity/damping after exit. Native Area
  gravity override stays disabled to prevent double application. Player sampling
  uses the same GravityZone API through a small InertialMovement component; ordinary
  FPS movement remains in its existing controller. Gravity is down-only with a
  vector acceleration API reserved for later extension.
- **Movement decisions:** 2.5 m/s² air control, 0.03 damping, 6 m/s controlled speed,
  4 m/s steering reserve; contact/landing replenishes it. This enables corrections
  without unlimited flight. Push-off adds up to 5 m/s, has a 0.35-movement-second
  cooldown and requires solid geometry or a ≥3 kg prop. Reactions on props are
  mass-dependent and bounded. Exiting a field retains airborne inertia until landing.
- **Physics/Focus:** fields use spatial feathering; transitions do not reset velocity.
  Nested zero-G blends over underlying low gravity instead of briefly restoring 1g.
  Objects retain ordinary world-time physics. Player movement keeps the established
  movement clock and throws inherit 65% of stored velocity, avoiding Focus compensation
  spikes. Coasting contacts can push props in 3D; grounded contact behavior is preserved.
- **Scene/controls:** F6 switches fresh arena/traversal scenes, Space jumps/pushes off,
  look + WASD steers, Backspace restarts the checkpoint with inventory intact, F5
  resets the entire current scene. Landing at departure/destination sets checkpoints.
  Falls clear movement/held actions and leave Focus. Fallen props are rescued with
  original identity and disarmed motion. Preplaced props return locally so the bridge
  remains populated during longer tests; thrown props return near the checkpoint. The original ten-object arena rain remains;
  the experimental scene has thirteen comparison/drifting props using existing types.
- **Files:** added `scenes/traversal.tscn`, `gravity_zone.gd`, `gravity_response.gd`,
  `inertial_movement.gd`, `traversal_lab.gd`, and `tests/iteration5_test.gd`. Updated
  player scene/controller, WorldItem launch inheritance, HUD, input map/test runner,
  README and both development documents. AGENTS records the broader experiment scope.
- **Validation:** 385 automated checks pass, including all 328 prior checks and 57
  new traversal checks. Verified field nesting/exit/deletion, zero/near-zero gravity,
  mass-dependent impulses/drift, finite 3D steering, wall/heavy-prop push-off, coasting
  contact impulses, Focus movement speed, inherited throws and recovery, checkpoints,
  prop rescue and scene switching. Actual run-and-jump bridge crossings succeed in
  normal time and with Focus entered/exited in midair across a field boundary. Normal
  crossing peaks at about 8.9 m and lands inside the destination backstop. Linux
  Compatibility renders were inspected for the start, corridor and bridge/HUD.
- **Known limits:** this is a static, down-gravity greybox feel experiment, not a new
  full mode. Push-off uses short rays, steering is finite, and gravity samples collider
  centers. Area enrollment can take a physics tick. Arena dummy gravity is unchanged;
  props/projectiles and the player support zones. F6 starts fresh and does not transfer
  inventory between labs. Windows and subjective movement feel still need playtests.
- **Suggested next steps:** collect feedback on inertia, steering reserve, push reach,
  zone feathering and crossing difficulty; tune exposed values before adding systems.
  No grappling, enemies, new weapons, sideways gravity, ceiling walking, selective
  freezing, detailed environments or story were implemented.
