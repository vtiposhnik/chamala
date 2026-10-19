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
