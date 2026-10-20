extends "res://tests/combat_test.gd"

func _initialize() -> void:
	create_timer(110.0, true, false, true).timeout.connect(func():
		push_error("Iteration 5 test timed out")
		quit(1)
	)
	run.call_deferred()

func run() -> void:
	await test_fields_and_rigid_bodies()
	await test_inertia_and_push_off()
	await test_focus_and_throws()
	await test_playground()
	arena.queue_free()
	await process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "traversal teardown restores normal global time")
	print("ITERATION 5 RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func zone(at: Vector3, dimensions: Vector3, gravity: float) -> GravityZone:
	var field := GravityZone.new()
	field.size = dimensions
	field.multiplier = gravity
	field.position = at
	arena.add_child(field)
	return field

func drift_fixture() -> GravityZone:
	await fixture()
	player.global_position = Vector3(0, 3, 4)
	player.head.rotation = Vector3.ZERO
	var field := zone(Vector3(0, 4, 0), Vector3(18, 8, 18), 0.0)
	await frames(3)
	player.traversal.update_field(1.0 / 60.0)
	return field

func test_fields_and_rigid_bodies() -> void:
	await fixture()
	var low := zone(Vector3(0, 4, 0), Vector3(16, 8, 16), 0.2)
	var zero := zone(Vector3(0, 4, 0), Vector3(6, 6, 6), 0.0)
	zero.priority = 2.0
	player.global_position = Vector3(0, 3.1, 0)
	check(is_zero_approx(GravityZone.sample(player).multiplier), "nested zero gravity overrides low gravity at its core")
	player.global_position.x = 2.5
	check(absf(GravityZone.sample(player).multiplier - 0.1) < 0.001, "nested boundary blends zero over underlying low gravity without a normal-gravity spike")
	player.global_position.x = 5.0
	check(absf(GravityZone.sample(player).multiplier - 0.2) < 0.001, "leaving nested pocket restores underlying low gravity")
	low.multiplier = 0.02
	check(absf(GravityZone.sample(player).multiplier - 0.02) < 0.001, "near-zero gravity is configurable independently of true zero")
	low.multiplier = 0.2
	player.global_position.x = 7.5
	check(absf(GravityZone.sample(player).multiplier - 0.6) < 0.001, "outer boundary smoothly blends back toward normal gravity")
	player.global_position.x = 8.1
	check(GravityZone.sample(player).multiplier == 1.0, "outside all zones gravity is normal")
	var light := body_at("baseball", Vector3(-1.5, 4, 0))
	var heavy := body_at("chair", Vector3(1.5, 4, 0))
	light.linear_velocity = Vector3(0, 0, 0.6)
	heavy.linear_velocity = Vector3(0, 0, 0.6)
	await frames(6)
	check(light.gravity_scale == 0.0 and heavy.gravity_scale == 0.0, "Area enrolls both light and heavy rigid bodies into zero gravity")
	var start := light.global_position
	var initial_velocity := light.linear_velocity
	await frames(30)
	check(light.global_position.z - start.z > 0.28, "lightweight prop drifts instead of losing momentum to ordinary damping")
	check(absf(light.linear_velocity.y - initial_velocity.y) < 0.01, "zero gravity stops acceleration without resetting existing vertical velocity")
	light.apply_central_impulse(Vector3.RIGHT)
	heavy.apply_central_impulse(Vector3.RIGHT)
	await frames(2)
	check(light.linear_velocity.x > 6.0 and heavy.linear_velocity.x > 0.1 and heavy.linear_velocity.x < 0.3, "equal impulses retain mass-dependent velocity changes")
	heavy.global_position = Vector3(8.5, 4, 0)
	heavy.linear_velocity = Vector3(0, 0, 1.0)
	await frames(3)
	check(heavy.gravity_scale == 1.0 and is_equal_approx(heavy.linear_damp, 0.15), "leaving zones restores original rigid-body gravity and damping")
	check(heavy.linear_velocity.z > 0.9, "field exit does not reset rigid-body momentum")
	zero.queue_free()
	await frames(2)
	player.global_position = Vector3(0, 3.1, 0)
	check(absf(GravityZone.sample(player).multiplier - 0.2) < 0.001, "removing a zone reveals the remaining field cleanly")
	low.queue_free()
	await frames(3)
	check(light.gravity_scale == 1.0, "zone deletion restores enrolled bodies to normal gravity")
	check(GravityZone.acceleration_for(0.2).is_equal_approx(Vector3(0, -1.96, 0)), "gravity vector API remains down-only")

func test_inertia_and_push_off() -> void:
	await drift_fixture()
	player.motion = Vector3(3, 0, -1)
	player.set_physics_process(true)
	var start := player.global_position
	await frames(30)
	check(player.global_position.x - start.x > 1.4 and player.motion.x > 2.9, "airborne zero-G player preserves momentum without input")
	check(absf(player.global_position.y - start.y) < 0.02, "player has no vertical acceleration in zero-G core")
	Input.action_press("move_left")
	await frames(1)
	check(player.motion.x > 2.8, "opposite input cannot instantly reverse velocity")
	Input.action_release("move_left")
	player.head.rotation.x = 0.5
	Input.action_press("move_forward")
	await frames(110)
	Input.action_release("move_forward")
	check(player.motion.y > 0.3, "camera-relative steering can change altitude")
	check(player.traversal.remaining_steering < 0.001, "air steering consumes a finite reserve instead of allowing unlimited flight")
	var vertical := player.motion.y
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	check(player.motion.y <= vertical + 0.001, "Space in free space cannot create an infinite midair jump")
	await drift_fixture()
	player.motion = Vector3(9, 0, 0)
	player.set_physics_process(true)
	Input.action_press("move_right")
	await frames(2)
	Input.action_release("move_right")
	check(player.motion.x > 8.9 and player.motion.x < 9.0, "controlled-speed limit preserves faster external momentum without adding more")
	await drift_fixture()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 5, 4)
	collider.shape = shape
	wall.add_child(collider)
	arena.add_child(wall)
	wall.position = Vector3(0.6, 3, 4)
	await frames(2)
	player.traversal.remaining_steering = 0.0
	check(player.traversal.try_push_off(), "nearby solid wall permits a push-off")
	check(player.motion.x < -4.9 and player.traversal.remaining_steering == player.traversal.steering_reserve, "wall push adds outward velocity and restores steering reserve")
	check(not player.traversal.try_push_off(), "push cooldown prevents stacked impulses from repeated calls")
	player.set_physics_process(true)
	await frames(30)
	check(player.global_position.x < -2.0, "push-off actually propels player through the space")
	check(not player.traversal.try_push_off(), "distant wall cannot provide another push")
	await drift_fixture()
	var chair := body_at("chair", player.global_position + Vector3(0.8, 0.9, 0))
	await frames(6)
	check(player.traversal.try_push_off(), "sufficiently massive floating chair supports push-off")
	await frames(2)
	check(chair.linear_velocity.x > 1.5 and player.motion.x < -4.9, "pushing a massive prop sends player and object in opposite directions")
	await drift_fixture()
	body_at("baseball", player.global_position + Vector3(0.6, 0.9, 0))
	await frames(6)
	check(not player.traversal.try_push_off(), "lightweight baseball cannot act as a push-off anchor")
	await drift_fixture()
	var drifting_chair := body_at("chair", Vector3(0, 3.9, 2.7))
	await frames(6)
	player.motion = Vector3(0, 0, -3)
	player.set_physics_process(true)
	await frames(30)
	check(drifting_chair.linear_velocity.z < -0.1, "coasting into a floating prop transfers momentum without held movement input")
	check(drifting_chair.linear_velocity.length() < 5.0, "inertial player contact retains bounded mass-dependent pushing")
	await drift_fixture()
	player.global_position = Vector3(8.2, 3, 0)
	player.motion = Vector3(2, 0, 0)
	player.set_physics_process(true)
	await frames(35)
	check(player.traversal.gravity_multiplier == 1.0 and player.motion.x > 1.9, "leaving gravity anomaly midair preserves horizontal momentum until landing")

func test_focus_and_throws() -> void:
	var distances: Array[float] = []
	for active in [false, true]:
		await drift_fixture()
		player.focus.set_active(active)
		await frames(16)
		player.motion = Vector3(3, 0, 0)
		player.set_physics_process(true)
		var start := player.global_position
		await frames(30)
		distances.append(player.global_position.x - start.x)
	check(absf(distances[1] / distances[0] - 0.75) < 0.02, "traversal movement retains the existing 75-percent Focus speed")
	await drift_fixture()
	player.motion = Vector3(2, 1, -3)
	var ball := await give("baseball")
	player.focus.set_active(true)
	await frames(16)
	check(player.throw_selected(), "safe physical throwing works in a zero-G field during Focus")
	var thrown: WorldItem = get_nodes_in_group("world_items")[0]
	var expected := Vector3.FORWARD * 24.0 + player.motion * player.traversal.throw_inheritance
	check(thrown.previous_velocity.is_equal_approx(expected), "traversal throw inherits logical movement momentum without Focus compensation spikes")
	await frames(16) # Include the real-time recovery/pickup lockout.
	check(thrown.gravity_scale == 0.0 and thrown.linear_velocity.length() < 30.0, "thrown body receives zone gravity while keeping bounded physical launch speed")
	thrown.freeze = true
	thrown.global_position = player.camera.global_position + Vector3.FORWARD * 2.0
	await frames(2)
	player.update_target()
	check(player.target == thrown and player.pick_up_target() and player.inventory.current_item() == ball, "drifting thrown object can be recovered with persistent item identity")
	player.set_physics_process(true)
	player.motion = Vector3(0.3, 0, -0.4)
	var stable := true
	for i in 12:
		player.focus.toggle()
		await frames(4)
		stable = stable and player.motion.is_finite() and player.motion.length() < 1.0
	check(stable, "rapid Focus toggles while airborne never create extreme player impulses")

func lab_fixture() -> void:
	for input in ["jump", "move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(input)
	if is_instance_valid(arena):
		arena.queue_free()
		await process_frame
	arena = load("res://scenes/traversal.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	player = arena.get_node("Player")
	await frames(20)

func test_playground() -> void:
	await lab_fixture()
	check(player.traversal.gravity_multiplier == 1.0 and player.is_on_floor(), "playground starts grounded in normal gravity")
	check(get_nodes_in_group("world_items").size() == 13, "comparison, corridor and bridge props all spawn without replacing the original rain")
	check(get_nodes_in_group("gravity_zones").size() == 3, "playground provides low, zero and bridge gravity zones")
	var gap_props: Array[Node] = get_nodes_in_group("world_items").filter(func(body): return body.get_meta("lab_home").z < -24.0)
	await frames(360)
	check(gap_props.size() == 3 and gap_props.all(func(body): return is_instance_valid(body) and body.global_position.y > -4.0), "gap comparison props return locally after falling and remain available for later traversal attempts")
	check(get_nodes_in_group("world_items").size() == 13, "repeated lab prop rescue never duplicates items")
	var item := await give("umbrella")
	player.global_position = Vector3(0, 0.1, -22)
	await frames(12)
	check(arena.checkpoint_stage == 1, "landing on departure platform activates bridge checkpoint")
	player.global_position.y = -12.0
	await frames(3)
	check(player.global_position.distance_to(arena.bridge_checkpoint) < 0.2 and player.motion.length() < 0.5, "falling automatically respawns at checkpoint with cleared fall velocity")
	check(player.inventory.current_item() == item, "checkpoint respawn preserves inventory identity")
	var lost: WorldItem = get_nodes_in_group("world_items")[0]
	var lost_item := lost.item
	lost.global_position.y = -12.0
	await frames(3)
	check(is_instance_valid(lost) and lost.global_position.y > 0.0 and lost.item == lost_item, "fallen prop is rescued without deletion or duplication")
	await frames(10)
	player.combat.primary(true)
	await frames(10)
	click("checkpoint_restart")
	check(not player.combat.behavior.held and player.motion == Vector3.ZERO, "Backspace cancels held actions and restarts safely")
	# Drive the actual character with movement input and a single ordinary jump.
	player.global_position = Vector3(0, 0.1, -22)
	await frames(12)
	Input.action_press("move_forward")
	await frames(13)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	var peak := player.global_position.y
	for i in 420:
		await frames(1)
		peak = maxf(peak, player.global_position.y)
		if arena.checkpoint_stage == 2:
			break
	Input.action_release("move_forward")
	print("BRIDGE MEASUREMENT position=", player.global_position, " peak=", peak, " checkpoint=", arena.checkpoint_stage)
	check(arena.checkpoint_stage == 2 and player.is_on_floor(), "single run-and-jump crosses the broken bridge and lands at destination")
	check(peak > 2.0 and peak < 12.0, "bridge jump follows a bounded low-gravity arc")
	# Repeat the crossing while entering Focus in the air, leaving the field
	# during Focus, then exiting Focus before landing.
	arena.checkpoint = arena.bridge_checkpoint
	arena.checkpoint_stage = 1
	arena.respawn_player()
	await frames(12)
	Input.action_press("move_forward")
	await frames(13)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	player.focus.set_active(true)
	var crossed_in_focus := false
	for i in 500:
		await frames(1)
		if player.global_position.z < -39.0 and player.traversal.gravity_multiplier > 0.99 and player.focus.active:
			crossed_in_focus = true
			player.focus.set_active(false)
		if arena.checkpoint_stage == 2:
			break
	Input.action_release("move_forward")
	check(crossed_in_focus, "airborne player crosses from low to normal gravity while Focus is active")
	check(arena.checkpoint_stage == 2 and player.motion.is_finite(), "Focus entry and midair exit preserve a successful bridge crossing")
	player.focus.set_active(true)
	await frames(16)
	click("switch_lab")
	await frames(5)
	arena = current_scene
	player = arena.get_node("Player")
	check(arena.scene_file_path == "res://scenes/arena.tscn" and get_nodes_in_group("world_items").size() == 10, "F6 returns to intact arena with original object rain")
	check(Engine.time_scale == 1.0 and get_nodes_in_group("gravity_zones").is_empty(), "scene switch removes gravity fields and resets Focus")
	click("switch_lab")
	await frames(5)
	arena = current_scene
	player = arena.get_node("Player")
	check(arena.scene_file_path == "res://scenes/traversal.tscn", "F6 opens traversal experiment from existing arena")
