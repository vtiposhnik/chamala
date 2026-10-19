extends "res://tests/combat_test.gd"
## Behavioral acceptance checks. Uses the same real arena fixtures as combat_test.

func _initialize() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func():
		push_error("Iteration 3 test timed out")
		quit(1)
	)
	run.call_deferred()

func run() -> void:
	await test_clocks_and_toggle()
	await test_pacing()
	await test_release_clearance()
	await test_flight_and_transitions()
	arena.queue_free()
	await process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "iteration 3 teardown restores normal time")
	print("ITERATION 3 RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func settle_focus(enabled: bool) -> void:
	player.focus.set_active(enabled)
	await frames(16)

func test_clocks_and_toggle() -> void:
	await fixture()
	check(not InputMap.has_action("drop"), "separate Drop binding is removed")
	click("focus")
	check(player.focus.active, "press and release Shift leaves Focus enabled")
	await frames(3)
	check(Engine.time_scale > 0.15 and Engine.time_scale < 1.0, "Focus enters through a smooth transition")
	var repeat: InputEventKey = InputMap.action_get_events("focus")[0].duplicate()
	repeat.pressed = true
	repeat.echo = true
	player._unhandled_input(repeat)
	check(player.focus.active, "keyboard repeat does not toggle Focus repeatedly")
	await frames(16)
	check(is_equal_approx(Engine.time_scale, 0.15), "Focus world settles to 15 percent real-time speed")
	check(is_equal_approx(player.focus.movement_scale(), 0.75), "movement clock settles to 75 percent")
	check(is_equal_approx(player.focus.action_scale(), 0.8), "action clock settles to 80 percent")
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(20, 10)
	var prior := player.pitch
	player._unhandled_input(mouse)
	check(is_equal_approx(player.pitch - prior, -10.0 * player.mouse_sensitivity), "camera look remains unscaled at 100 percent")
	click("focus")
	check(not player.focus.active, "second Shift press disables Focus")
	await frames(16)
	check(is_equal_approx(Engine.time_scale, 1.0), "exit transition restores normal world time")
	var travel: Array[float] = []
	for enabled in [false, true]:
		player.set_physics_process(false)
		await settle_focus(enabled)
		player.global_position = Vector3(6, 0, 7)
		player.rotation = Vector3.ZERO
		player.head.rotation = Vector3.ZERO
		player.motion = Vector3.ZERO
		player.set_physics_process(true)
		Input.action_press("move_forward")
		await frames(30)
		var start := player.position.z
		await frames(60)
		travel.append(start - player.position.z)
		Input.action_release("move_forward")
	print("MOVEMENT normal=%.3f focus=%.3f ratio=%.3f" % [travel[0], travel[1], travel[1] / travel[0]])
	check(absf(travel[0] - player.move_speed) < 0.12, "normal movement speed is preserved")
	check(absf(travel[1] / travel[0] - 0.75) < 0.025, "measured Focus travel is approximately 75 percent of normal")

func test_pacing() -> void:
	for enabled in [false, true]:
		await fixture()
		await settle_focus(enabled)
		var scale := 0.8 if enabled else 1.0
		var mode := "Focus" if enabled else "Normal"
		var pistol := await give("pistol")
		action("primary")
		var previous_rounds := pistol.rounds
		var intervals: Array[float] = []
		var ticks := 0
		for i in 240:
			await frames(1)
			ticks += 1
			if pistol.rounds < previous_rounds:
				intervals.append(ticks / 60.0)
				ticks = 0
				previous_rounds = pistol.rounds
			if intervals.size() == 7:
				break
		action("primary", false)
		var expected := 1.0 / (4.5 * scale)
		check(intervals.size() == 7, mode + " rapid fire executes seven successive intervals")
		check(intervals.all(func(value): return absf(value - expected) < 0.035), mode + " pistol intervals match 4.5 shots/sec on the action clock")
		var average: float = intervals.reduce(func(total, value): return total + value, 0.0) / maxf(intervals.size(), 1)
		check(absf(average - expected) < 0.008, mode + " sustained fire preserves fractional tick cadence")
		print(mode, " PISTOL intervals=", intervals)
		pistol.rounds = 0
		click("reload")
		ticks = 0
		while pistol.rounds == 0 and ticks < 120:
			await frames(1)
			ticks += 1
		print(mode, " RELOAD seconds=", ticks / 60.0)
		check(pistol.rounds == 12 and absf(ticks / 60.0 - 1.1 / scale) < 0.04, mode + " reload duration matches 1.1 action seconds")
		await fixture()
		await settle_focus(enabled)
		player.global_position = Vector3(0, 0, -5.4)
		player.head.look_at(dummy.get_node("Body").global_position)
		await give("frying_pan")
		var hits := [0]
		var damage_values: Array[float] = []
		player.hit_confirmed.connect(func(damage: float):
			hits[0] += 1
			damage_values.append(damage)
			dummy.reset()
		)
		action("primary")
		var previous_hits: int = hits[0]
		intervals.clear()
		ticks = 0
		for i in 240:
			await frames(1)
			ticks += 1
			if hits[0] > previous_hits:
				intervals.append(ticks / 60.0)
				ticks = 0
				previous_hits = hits[0]
			if intervals.size() == 5:
				break
		action("primary", false)
		expected = 1.0 / (2.0 * scale)
		check(intervals.size() == 5 and intervals.all(func(value): return absf(value - expected) < 0.035), mode + " pan chains at two swings/sec on the action clock")
		check(damage_values.size() == 6 and damage_values.all(func(value): return value == 25.0), mode + " each pan swing deals exactly one 25-damage hit")
		print(mode, " PAN intervals=", intervals)
		await frames(45)
		click("secondary")
		ticks = 0
		while player.combat.behavior.parry_remaining > 0.0 and ticks < 60:
			await frames(1)
			ticks += 1
		check(absf(ticks / 60.0 - 0.25 / scale) < 0.035, mode + " parry window follows player-action time")
		await fixture()
		await settle_focus(enabled)
		await give("baseball")
		action("primary")
		ticks = 0
		while player.combat.behavior.charge_fraction() < 1.0 and ticks < 100:
			await frames(1)
			ticks += 1
		check(absf(ticks / 60.0 - 1.0 / scale) < 0.035, mode + " full baseball charge takes one action second")
		player.combat.cancel_action()
		player.equipped.animate_action(&"reload", 0.5)
		ticks = 0
		while player.equipped.remaining > 0.0 and ticks < 60:
			await frames(1)
			ticks += 1
		check(absf(ticks / 60.0 - 0.5 / scale) < 0.035, mode + " 0.5-second viewmodel animation scales once")
		var item := ItemInstance.new(definition("pistol"))
		player.inventory.add_item(item)
		ticks = 0
		while player.combat.switch_remaining > 0.0 and ticks < 30:
			await frames(1)
			ticks += 1
		check(absf(ticks / 60.0 - player.combat.switch_seconds / scale) < 0.035, mode + " weapon switch uses the action clock")
		player.global_position = Vector3(0, 0, 6)
		player.head.rotation = Vector3.ZERO
		check(player.throw_selected(), mode + " generic throw releases successfully")
		ticks = 0
		while player.combat.throw_remaining > 0.0 and ticks < 60:
			await frames(1)
			ticks += 1
		check(absf(ticks / 60.0 - item.definition.throw_recovery / scale) < 0.035, mode + " throw recovery follows action time")

func has_overlap(body: WorldItem, mask: int, contact_tolerance: float = 0.0) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body.item.definition.create_world_shape()
	if query.shape is BoxShape3D:
		query.shape.size = (query.shape.size - Vector3.ONE * contact_tolerance * 2.0).max(Vector3.ONE * 0.002)
	else:
		query.shape.radius = maxf(0.001, query.shape.radius - contact_tolerance)
	query.transform = body.global_transform
	query.collision_mask = mask
	query.exclude = [body.get_rid()]
	return not player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func test_release_clearance() -> void:
	for id in ["baseball", "pistol", "frying_pan", "chair", "umbrella"]:
		await fixture()
		player.global_position = Vector3(0, 0, -9.35)
		player.head.rotation = Vector3.ZERO
		var item := await give(id)
		var success := player.throw_selected()
		check(success, id + " can be thrown while facing a wall at close range")
		if not success:
			continue
		var body: WorldItem = get_nodes_in_group("world_items")[0]
		check(not has_overlap(body, 1 | 2 | 4 | 8), id + " releases outside both player and environment")
		check(body.item == item and player.inventory.current_item() == null, id + " transfers identity to exactly one world body")
		await frames(60)
		check(body.global_position.z > -9.85 and body.global_position.y > -0.1, id + " stays inside arena after wall collision")
		await frames(120) # Distinguish an impact-resolution frame from permanent embedding.
		# The solver allows ~1 cm of resting contact penetration. Test beyond
		# that skin, rather than a percentage that unfairly penalizes thin props.
		check(not has_overlap(body, 1, 0.012), id + " has no deep persistent wall/floor penetration")
		check(body.collision_mask & 1 != 0, id + " keeps environment collisions enabled")
	await fixture()
	player.global_position = Vector3(0, 0, 5)
	player.head.rotation = Vector3.ZERO
	var chair := body_at("chair", Vector3(0, 1.65, 4.1))
	chair.gravity_scale = 0.0
	await give("baseball")
	check(player.throw_selected(), "nearby chair does not arbitrarily block baseball release")
	await frames(12)
	check(chair.linear_velocity.length() > 0.1, "thrown baseball physically collides with and moves nearby chair")
	await fixture()
	player.global_position = Vector3(0, 0, 5)
	player.head.rotation.x = -1.4
	await give("chair")
	check(player.throw_selected(), "downward heavy throw finds release clear of floor and player")
	var heavy: WorldItem = get_nodes_in_group("world_items")[0]
	check(not has_overlap(heavy, 1 | 2), "heavy downward throw starts outside floor and player")
	await frames(90)
	check(heavy.global_position.y > -0.1, "heavy downward throw does not tunnel through floor")
	check(not has_overlap(heavy, 1, 0.012), "heavy downward throw does not remain embedded in floor")
	await fixture()
	player.global_position = Vector3(0, 0, 5)
	player.head.rotation = Vector3.ZERO
	for id in ["pistol", "chair", "frying_pan", "baseball", "umbrella"]:
		await give(id)
	var selected := player.inventory.current_item()
	check(player.inventory.is_full() and player.throw_selected(), "full inventory can throw its selected object")
	check(player.inventory.slots.count(null) == 1 and get_nodes_in_group("world_items").size() == 1, "full inventory throw removes only one item")
	var released: WorldItem = get_nodes_in_group("world_items")[0]
	check(released.item == selected, "full inventory throw preserves identity")
	check(not player.throw_selected(), "empty slot throw is harmless")
	player.inventory.select(0)
	check(not player.throw_selected(), "switching cannot bypass throw recovery")
	await fixture()
	player.global_position = Vector3(0, 0, 5)
	player.head.rotation = Vector3.ZERO
	var retained := await give("chair")
	# An enclosed 0.9m-wide test booth admits the player, but no chair can fit
	# beside, ahead of, behind or above the body without intersecting a wall.
	var walls: Array[Vector3] = [Vector3(0.65, 1.2, 5), Vector3(-0.65, 1.2, 5), Vector3(0, 1.2, 4.35), Vector3(0, 1.2, 5.65), Vector3(0, 2.15, 5)]
	for i in walls.size():
		var obstacle := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.4, 2.5, 2.0) if i < 2 else Vector3(2.0, 2.5, 0.4)
		if i == 4:
			shape.size = Vector3(2, 0.4, 2)
		collider.shape = shape
		obstacle.add_child(collider)
		arena.add_child(obstacle)
		obstacle.position = walls[i]
	await frames(2)
	check(not player.throw_selected(), "genuinely impossible release fails safely")
	check(player.inventory.current_item() == retained and get_nodes_in_group("world_items").is_empty(), "impossible release neither loses nor duplicates the item")

func test_flight_and_transitions() -> void:
	await fixture()
	player.global_position = Vector3(6, 0, 5)
	player.head.rotation = Vector3.ZERO
	await settle_focus(true)
	await give("baseball")
	check(player.throw_selected(), "baseball releases immediately during Focus")
	var ball: WorldItem = get_nodes_in_group("world_items")[0]
	await frames(2)
	check(ball.linear_velocity.length() > 20.0 and ball.linear_velocity.length() < 25.0, "Focus does not multiply or divide launch velocity")
	var start := ball.global_position
	await frames(20)
	var travel := start.distance_to(ball.global_position)
	check(travel > 0.8 and travel < 1.4, "released baseball travels at slowed world speed")
	# Compare two identical launches after equal accumulated world time, one
	# with repeated transitions. Gravity and damping should yield the same path.
	var samples: Array[Vector3] = []
	for toggling in [false, true]:
		await fixture()
		var projectile := body_at("baseball", Vector3(6, 5, 6))
		projectile.launch(Vector3.FORWARD, 0.25, null)
		await frames(2)
		var world_time := 0.0
		var tick := 0
		var bounded := true
		while world_time < 0.5:
			if toggling and tick % 18 == 0:
				click("focus")
			var scale_before := Engine.time_scale
			await frames(1)
			world_time += scale_before / 60.0
			tick += 1
			bounded = bounded and projectile.linear_velocity.length() < 10.0
		check(bounded, "midair Focus transitions keep velocity bounded throughout flight")
		samples.append(projectile.global_position)
	print("TRAJECTORY equal-world-time error=", samples[0].distance_to(samples[1]))
	check(samples[0].distance_to(samples[1]) < 0.18, "midair transitions preserve trajectory for equal world elapsed time")
	await fixture()
	player.global_position = Vector3(6, 0, 7)
	player.head.rotation = Vector3.ZERO
	var pistol := await give("pistol")
	player.set_physics_process(true)
	Input.action_press("move_forward")
	action("primary")
	var stable := true
	for i in 120:
		if i % 7 == 0:
			click("focus")
		var old_position := player.global_position
		await frames(1)
		stable = stable and player.global_position.distance_to(old_position) < 0.15
		stable = stable and Engine.time_scale >= 0.149 and Engine.time_scale <= 1.001
		stable = stable and pistol.rounds >= 0 and pistol.attack_cooldown >= 0.0
	action("primary", false)
	Input.action_release("move_forward")
	check(stable, "rapid toggles while moving and firing have no displacement or cooldown spikes")
	check(pistol.rounds < 12 and player.inventory.current_item() == pistol and get_nodes_in_group("world_items").is_empty(), "rapid toggles preserve attacks and inventory without duplication")
