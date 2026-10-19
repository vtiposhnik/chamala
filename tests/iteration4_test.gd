extends "res://tests/combat_test.gd"
## Exercise real flight and contacts, not just direct defense callbacks.

func _initialize() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func():
		push_error("Iteration 4 test timed out")
		quit(1)
	)
	run.call_deferred()

func run() -> void:
	await test_capabilities_and_chair()
	await test_umbrella()
	await test_deflection()
	await test_projectile_safety()
	await test_launcher_and_focus()
	arena.queue_free()
	await process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "iteration 4 teardown restores global time")
	print("ITERATION 4 RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func shot(at: Vector3, direction: Vector3, speed: float = 12.0, category: int = 1) -> PhysicalProjectile:
	var body := PhysicalProjectile.new()
	body.data = ProjectileDefinition.new()
	body.data.speed = speed
	body.data.category = category
	arena.add_child(body)
	body.global_position = at
	body.launch(direction)
	return body

func defense_fixture(id: String) -> void:
	await fixture()
	player.global_position = Vector3(0, 0, 4)
	player.head.rotation = Vector3.ZERO
	await give(id)

func test_capabilities_and_chair() -> void:
	await fixture()
	for id in ["chair", "umbrella", "frying_pan", "pistol", "baseball"]:
		var item := await give(id)
		check(player.combat.behavior != null and player.equipped.item == item, id + " has its own working equipped behavior")
		check(item.definition.has_capability(WeaponDefinition.Capability.THROWABLE) and item.definition.has_capability(WeaponDefinition.Capability.RECOVERABLE), id + " supports throwing and recovery")
	check(player.inventory.is_full(), "all five distinct items fit the unchanged inventory")
	player.inventory.select(0)
	await frames(10)
	check("RMB" not in player.combat.status_text() and "Reload" not in player.combat.status_text(), "chair hints expose only its available action")
	var chair_item := player.inventory.current_item()
	var before := dummy.global_position
	click("primary")
	check(player.inventory.current_item() == null, "chair main action removes it from the inventory")
	var chair: WorldItem = get_nodes_in_group("world_items")[0]
	await frames(2)
	check(chair.item == chair_item and chair.mass == 6.0, "heavy throw preserves identity and six-kilogram mass")
	check(chair.linear_velocity.length() > 9.0 and chair.linear_velocity.length() < 11.0, "chair impulse produces about 10 m/s, slower than baseball")
	check(chair.angular_velocity.length() > 0.0, "released chair tumbles physically")
	await frames(40)
	check(dummy.health.current < 60.0, "direct chair hit deals substantial speed-based damage")
	check(dummy.global_position.distance_to(before) > 0.15, "chair hit physically displaces the dummy")
	var after: float = dummy.health.current
	await frames(160)
	check(dummy.health.current == after, "one chair launch cannot damage a target repeatedly")
	check(is_instance_valid(chair) and chair.can_pick_up() and chair.global_position.y > -0.1, "chair stays in the world above the floor and remains recoverable")
	chair.freeze = true
	chair.global_position = player.camera.global_position - player.camera.global_basis.z * 2.0
	await frames(2)
	player.update_target()
	check(player.target == chair and player.pick_up_target(), "thrown chair can be picked up again")
	check(player.inventory.current_item() == chair_item, "recovered chair is the original item")
	click("reset_dummy")
	check(get_nodes_in_group("test_dummies").size() == 3, "arena contains three damageable test dummies")
	check(dummy.global_position.distance_to(before) < 0.02, "T restores displaced dummy to its start position")
	await fixture()
	player.global_position = Vector3(7, 0, 6)
	player.head.rotation = Vector3.ZERO
	await give("chair")
	click("primary")
	var flying: WorldItem = get_nodes_in_group("world_items")[0]
	var bounded := true
	for i in 8:
		player.focus.toggle()
		await frames(4)
		bounded = bounded and is_instance_valid(flying) and flying.linear_velocity.length() < 12.0
	check(bounded and get_nodes_in_group("world_items").size() == 1, "Focus toggles during chair flight cause no extreme impulses, loss or duplicates")

func test_umbrella() -> void:
	await defense_fixture("umbrella")
	check("RMB" not in player.combat.status_text(), "umbrella has no unavailable secondary attack hint")
	action("primary")
	await frames(10)
	check(player.combat.behavior.openness == 1.0 and player.equipped.visual.umbrella_canopy.scale.x > 5.0, "holding LMB fully opens the visible canopy")
	var front := shot(Vector3(0, 1.45, 1), Vector3.BACK)
	await frames(20)
	check(not is_instance_valid(front) and player.damage_taken == 0.0 and player.blocks == 1, "open umbrella consumes a frontal projectile without player damage")
	shot(Vector3(3, 1.45, 4), Vector3.LEFT)
	await frames(20)
	check(player.damage_taken == 10.0, "side projectile passes umbrella protection")
	shot(Vector3(0, 1.45, 7), Vector3.FORWARD)
	await frames(20)
	check(player.damage_taken == 20.0, "rear projectile remains dangerous")
	for angle in [55.0, 65.0]:
		var toward := Vector3(sin(deg_to_rad(angle)), 0, -cos(deg_to_rad(angle)))
		shot(Vector3(0, 1.45, 4) + toward * 2.0, -toward)
		await frames(15)
	check(player.blocks == 2 and player.damage_taken == 30.0, "120-degree protection blocks 55 degrees and rejects 65 degrees")
	shot(Vector3(0, 1.45, 1), Vector3.BACK, 12.0, 2)
	await frames(20)
	check(player.damage_taken == 40.0, "heavy projectile category bypasses standard umbrella protection")
	var heavy := body_at("chair", Vector3(0, 1.4, 2.5))
	heavy.gravity_scale = 0.0
	heavy.launch(Vector3.BACK, 1.0, null)
	await frames(20)
	check(player.damage_taken > 70.0 and heavy.projectile_active, "physical thrown chair is not neutralized by the umbrella")
	heavy.queue_free()
	var prior := player.damage_taken
	action("primary", false)
	shot(Vector3(0, 1.45, 3.4), Vector3.BACK)
	await frames(4)
	check(player.damage_taken == prior + 10.0, "releasing the button immediately ends protection while closing")
	await frames(10)
	check(player.equipped.visual.umbrella_canopy.scale.x == 1.0, "released umbrella visibly closes")
	action("primary")
	await frames(10)
	await give("pistol")
	check(not player.combat.behaviors[WeaponDefinition.Kind.UMBRELLA].held, "switching cancels umbrella block")
	player.inventory.select(0)
	await frames(10)
	check(player.combat.behavior.openness == 0.0, "reequipping starts with umbrella closed")
	action("primary")
	await frames(10)
	click("throw")
	check(player.inventory.current_item() == null and not player.combat.behaviors[WeaponDefinition.Kind.UMBRELLA].held, "throwing cancels active block and removes the umbrella")
	var released: WorldItem = get_nodes_in_group("world_items")[0]
	check(released.visual.umbrella_canopy.scale.x == 1.0 and released.item.definition.id == &"umbrella", "world umbrella stays closed and recoverable")
	await defense_fixture("umbrella")
	player.focus.set_active(true)
	await frames(16)
	action("primary")
	await frames(6)
	check(player.combat.behavior.openness < 1.0, "Focus shield startup uses action time")
	await frames(5)
	check(player.combat.behavior.openness == 1.0, "Focus shield opens after about 0.15 real seconds")
	shot(Vector3(0, 1.45, 3.2), Vector3.BACK)
	await frames(18)
	check(player.blocks == 1 and player.damage_taken == 0.0, "umbrella blocks actual flight during Focus")
	player.set_mouse_captured(false)
	check(not player.combat.behavior.held and player.equipped.shield_open == 0.0, "mouse release cancels blocking and visual state")

func test_deflection() -> void:
	await fixture()
	player.global_position = Vector3(0, 0, -2)
	player.head.rotation = Vector3.ZERO
	await give("frying_pan")
	var incoming := shot(Vector3(0, 1.45, -3.4), Vector3.BACK)
	click("primary")
	await frames(6)
	check(is_instance_valid(incoming) and incoming.launch_owner == player and incoming.linear_velocity.z < -5.0, "timed LMB pan swing deflects actual incoming projectile toward aim")
	check(player.damage_taken == 0.0, "successful deflection prevents player damage")
	check(player.equipped.animation == &"parry_success", "deflection gives a visible contact flash/pose")
	await frames(35)
	check(dummy.health.current == 90.0, "deflected projectile reaches and damages the dummy once")
	check(not is_instance_valid(incoming), "projectile cleans up after hitting the dummy")
	check(player.damage_taken == 0.0, "reflected projectile does not immediately recollide with player")
	click("primary")
	await frames(18)
	shot(Vector3(0, 1.45, -3), Vector3.BACK)
	await frames(8)
	check(player.damage_taken == 10.0, "late incoming projectile damages player after swing window closes")
	await frames(20)
	click("secondary")
	var hard := shot(Vector3(0, 1.45, -3), Vector3.BACK)
	hard.data.deflectable = false
	await frames(8)
	check(player.damage_taken == 20.0, "nondeflectable projectile bypasses pan")
	await frames(30)
	player.focus.set_active(true)
	await frames(16)
	click("secondary")
	var slow := shot(Vector3(0, 1.45, -2.65), Vector3.BACK)
	await frames(14)
	check(is_instance_valid(slow) and slow.launch_owner == player, "RMB parry reflects real projectile during Focus")
	check(player.damage_taken == 20.0, "Focus reflection preserves damage prevention")
	await fixture()
	player.head.rotation = Vector3.ZERO
	var pan := await give("frying_pan")
	click("throw")
	var physical_pan: WorldItem = get_nodes_in_group("world_items")[0]
	await frames(45)
	check(dummy.health.current < 100.0, "thrown pan damages dummy on physical impact")
	var after: float = dummy.health.current
	await frames(150)
	check(dummy.health.current == after and physical_pan.item == pan and physical_pan.can_pick_up(), "thrown pan damages once and remains the same recoverable item")

func test_projectile_safety() -> void:
	await fixture()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 3, 0.02)
	collider.shape = shape
	wall.add_child(collider)
	arena.add_child(wall)
	wall.position = Vector3(4, 2, 0)
	await frames(2)
	var fast := shot(Vector3(4, 2, 2), Vector3.FORWARD, 300.0)
	var outcomes: Array[String] = []
	fast.resolved.connect(func(result, _speed, _damage): outcomes.append(result))
	await frames(3)
	check(not is_instance_valid(fast) and outcomes == ["obstacle"], "300 m/s sphere cannot tunnel through a 2cm wall or resolve twice")
	wall.queue_free()
	await frames(2)
	var overlapping := shot(Vector3(10, 2, 0), Vector3.FORWARD)
	await frames(2)
	check(not is_instance_valid(overlapping), "projectile starting in a wall is safely retired")
	var expires := shot(Vector3(5, 5, 0), Vector3.LEFT, 0.1)
	expires.data.lifetime = 0.05
	await frames(5)
	check(not is_instance_valid(expires), "projectile lifetime cleanup is bounded")
	for i in 30:
		var body := shot(Vector3(-7 + (i % 6) * 2, 4.0 + (i / 6) * 0.3, 2), Vector3.FORWARD, 25.0)
		body.data.lifetime = 0.4
	await frames(30)
	check(get_nodes_in_group("projectiles").is_empty(), "30 simultaneous projectiles clean up without runaway accumulation")

func test_launcher_and_focus() -> void:
	await defense_fixture("umbrella")
	var launcher: ProjectileLauncher = arena.get_node("Launcher")
	check(not launcher.enabled, "launcher starts disabled")
	var toggle: InputEvent = InputMap.action_get_events("toggle_launcher")[0].duplicate()
	toggle.pressed = true
	launcher._unhandled_input(toggle)
	check(launcher.enabled, "L enables launcher through its input action")
	launcher._unhandled_input(toggle)
	check(not launcher.enabled, "second L press disables launcher")
	launcher.global_position = dummy.get_node("Body").global_position
	check(launcher.fire() == null and dummy.health.current == 100.0, "obstructed muzzle does not spawn inside or damage a dummy")
	player.global_position = Vector3(0, 0, -3)
	launcher.placement = 0
	launcher.place_relative_to_player()
	check(launcher.clear_muzzle(launcher.global_position) and launcher.global_position.distance_to(dummy.global_position + Vector3.UP * 1.65) > 0.75, "station search avoids spawning launcher inside a nearby dummy")
	player.global_position = Vector3(0, 0, 4)
	launcher.placement = 0
	launcher.place_relative_to_player()
	check(launcher.global_position.z < player.global_position.z, "launcher front station is ahead of player")
	launcher.placement = 1
	launcher.place_relative_to_player()
	check(launcher.global_position.x > player.global_position.x, "launcher side station is beside player")
	launcher.placement = 2
	launcher.place_relative_to_player()
	check(launcher.global_position.z > player.global_position.z, "launcher rear station is behind player")
	launcher.interval = 0.2
	launcher.enabled = true
	launcher.remaining = 0.2
	await frames(31)
	check(launcher.shots_fired == 2, "launcher repeats on configurable world-time interval")
	launcher.enabled = false
	var fired := launcher.shots_fired
	await frames(30)
	check(launcher.shots_fired == fired, "disabled launcher stops automatic firing")
	for body in get_nodes_in_group("projectiles"):
		body.queue_free()
	await frames(2)
	player.focus.set_active(true)
	await frames(16)
	launcher.enabled = true
	launcher.remaining = 0.2
	await frames(30)
	check(launcher.shots_fired == fired, "Focus slows launcher interval with the world clock")
	launcher.enabled = false
	var single: InputEvent = InputMap.action_get_events("fire_launcher")[0].duplicate()
	single.pressed = true
	launcher._unhandled_input(single)
	check(launcher.shots_fired == fired + 1, "J single-fires even while automatic mode is off")
	for body in get_nodes_in_group("projectiles"):
		body.queue_free()
	await frames(2)
	var world_shot := shot(Vector3(7, 5, 7), Vector3.FORWARD)
	var start := world_shot.global_position
	await frames(30)
	check(world_shot.global_position.distance_to(start) > 0.8 and world_shot.global_position.distance_to(start) < 1.0, "Focus projectile travels about 0.9m in half a real second")
	check(absf(world_shot.linear_velocity.length() - 12.0) < 0.01, "Focus never rescales physical projectile velocity")
	action("primary")
	await frames(12)
	var stable := true
	for i in 8:
		player.focus.toggle()
		await frames(4)
		stable = stable and is_instance_valid(world_shot) and absf(world_shot.linear_velocity.length() - 12.0) < 0.01
	check(stable and player.combat.behavior.openness == 1.0, "rapid Focus toggles preserve projectile speed and held umbrella state")
	click("reset_dummy")
	check(player.damage_taken == 0.0 and player.hits_received == 0, "T resets player test damage along with all dummies")
