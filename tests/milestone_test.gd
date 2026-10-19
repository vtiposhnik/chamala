extends SceneTree
## Run: godot --headless --path . --script res://tests/milestone_test.gd
## Exercises the actual arena, physics queries, inventory and player input handlers.

var failures: int = 0
var checks: int = 0
var arena: Node3D
var player: RainPlayer

func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func():
		push_error("Milestone checks timed out before completion")
		quit(1)
	)
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func key_action(action: String) -> void:
	# Dispatch the configured physical key or wheel event, not a synthetic action name.
	var event: InputEvent = InputMap.action_get_events(action)[0].duplicate()
	event.pressed = true
	player._unhandled_input(event)

func run() -> void:
	arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	player = arena.get_node("Player")
	await frames(2)
	var viewport_rect := root.get_visible_rect()
	var hud := arena.get_node("HUD")
	check(viewport_rect.encloses(hud.get_node("Layout/InventorySlots").get_global_rect()), "all five HUD slots stay inside viewport")
	check(viewport_rect.encloses(hud.get_node("Layout/FocusStatus").get_global_rect()), "Focus status stays inside viewport")
	check(hud.crosshair.get_global_rect().has_point(viewport_rect.get_center()), "crosshair is centered in viewport")
	check(get_nodes_in_group("world_items").size() == 10, "exactly ten physical objects spawn")
	var kinds: Dictionary = {}
	for body in get_nodes_in_group("world_items"):
		kinds[body.item.definition.kind] = true
		check(body is RigidBody3D and body.continuous_cd, "rain object uses continuous rigid-body collision")
	check(kinds.size() == 5, "all five distinct definitions spawn")
	check(player.inventory.slots.size() == 5 and player.inventory.current_item() == null, "five initially empty slots")
	key_action("slot_5")
	check(player.inventory.selected_index == 4 and player.equipped.item == null, "number input selects empty slot safely")
	key_action("next_slot")
	check(player.inventory.selected_index == 0, "wheel next wraps to first slot")
	key_action("previous_slot")
	check(player.inventory.selected_index == 4, "wheel previous wraps to last slot")
	key_action("slot_1")
	check(not player.drop_selected(), "dropping an empty slot is safe")
	await frames(240)
	for body in get_nodes_in_group("world_items"):
		check(body.global_position.y > -0.1 and body.global_position.y < 1.2, "falling object settles above floor")
	check(player.is_on_floor(), "player lands on arena floor")
	player.set_physics_process(false)
	var collected: Array[ItemInstance] = []
	for i in 5:
		var body: WorldItem = get_nodes_in_group("world_items")[0]
		body.freeze = true
		body.global_position = Vector3(0, 1.65, 3.6)
		body.rotation = Vector3.ZERO
		player.global_position = Vector3(0, 0, 6)
		player.rotation = Vector3.ZERO
		player.head.rotation = Vector3.ZERO
		await frames(2)
		player.update_target()
		check(player.target == body, "ray targets visible physical object")
		check(body.visual.materials[0].emission_enabled, "target gains visible highlight")
		collected.append(body.item)
		check(player.pick_up_target(), "pickup inserts object into inventory")
		check(body.claim() == null, "same world object cannot be claimed twice")
		await frames(2)
		check(player.equipped.item == collected[i], "equipped model uses picked-up identity")
	check(get_nodes_in_group("world_items").size() == 5, "pickup removes each physical world representation")
	check(player.inventory.is_full(), "inventory fills at five objects")
	var rejected: WorldItem = get_nodes_in_group("world_items")[0]
	rejected.freeze = true
	rejected.global_position = Vector3(0, 1.65, 3.6)
	await frames(2)
	player.update_target()
	check(not player.pick_up_target() and not rejected.is_claimed, "full inventory leaves targeted world item intact")
	rejected.freeze = false
	key_action("slot_1")
	check(player.equipped.item == collected[0], "switching equips the correct stored identity")
	collected[0].rounds = 7
	player.global_position = Vector3(8.7, 0, 6)
	player.rotation.y = -PI / 2.0
	await frames(2)
	check(not player.drop_selected() and player.inventory.current_item() == collected[0], "wall-obstructed drop retains inventory item")
	player.global_position = Vector3(0, 0, 8)
	player.rotation.y = 0
	await frames(2)
	check(player.drop_selected(), "clear-space drop succeeds")
	await frames(2)
	check(player.inventory.current_item() == null and player.equipped.item == null, "drop clears slot and equipped model")
	check(get_nodes_in_group("world_items").size() == 6, "drop restores exactly one physical representation")
	var dropped: WorldItem
	for body in get_nodes_in_group("world_items"):
		if body.item == collected[0]:
			dropped = body
	check(dropped != null and dropped.item.rounds == 7, "mutable item state survives dropping")
	check(not dropped.can_pick_up(), "drop prevents immediate accidental repickup")
	await frames(20)
	check(dropped.can_pick_up(), "dropped object becomes recoverable")
	# A real ray cannot select an item behind an arena wall.
	dropped.freeze = true
	dropped.global_position = Vector3(0, 1.65, 11)
	player.global_position = Vector3(0, 0, 8.5)
	player.rotation.y = PI
	await frames(2)
	player.update_target()
	check(player.target == null, "arena collision occludes pickup ray")
	dropped.global_position = Vector3(-7, 5, 4)
	dropped.freeze = false
	dropped.linear_velocity = Vector3.ZERO
	dropped.angular_velocity = Vector3.ZERO
	await frames(12)
	var normal_fall := 5.0 - dropped.global_position.y
	dropped.freeze = true
	dropped.global_position = Vector3(-7, 5, 4)
	await frames(2)
	player.focus.set_active(true)
	dropped.freeze = false
	dropped.linear_velocity = Vector3.ZERO
	await frames(12)
	var slow_fall := 5.0 - dropped.global_position.y
	check(is_equal_approx(Engine.time_scale, 0.1), "Focus sets configured time scale")
	check(normal_fall > 0.05 and slow_fall < normal_fall * 0.15, "Focus measurably slows gravity-driven objects")
	player.focus.set_active(false)
	check(is_equal_approx(Engine.time_scale, 1.0), "Focus restores normal simulation speed")
	# Compare measured player travel under the same real-time input duration.
	player.global_position = Vector3(6, 0, 6)
	player.rotation = Vector3.ZERO
	player.motion = Vector3.ZERO
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(40)
	var normal_travel := 6.0 - player.global_position.z
	Input.action_release("move_forward")
	player.global_position = Vector3(6, 0, 6)
	player.motion = Vector3.ZERO
	Input.action_press("focus")
	Input.action_press("move_forward")
	await frames(40)
	var focus_travel := 6.0 - player.global_position.z
	check(normal_travel > 2.0 and absf(normal_travel - focus_travel) < 0.25, "movement stays responsive during Focus")
	var before_pitch := player.pitch
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(20, 10)
	player._unhandled_input(mouse)
	check(is_equal_approx(player.pitch - before_pitch, -10 * player.mouse_sensitivity), "camera input is independent of time scale")
	Input.action_release("move_forward")
	Input.action_release("focus")
	player.set_mouse_captured(false)
	check(is_equal_approx(Engine.time_scale, 1.0), "releasing mouse resets Focus")
	var dummy := arena.get_node("Dummy")
	dummy.apply_damage(25.0)
	check(dummy.health.current == 75.0 and "075" in dummy.label.text, "dummy health and visible status respond to damage")
	dummy.apply_damage(-10.0)
	check(dummy.health.current == 75.0, "health ignores negative damage")
	dummy.apply_damage(1000.0)
	check(dummy.health.current == 0.0, "health clamps lethal damage at zero")
	var pistol: WeaponDefinition = load("res://resources/weapons/pistol.tres")
	var chair: WeaponDefinition = load("res://resources/weapons/chair.tres")
	check(pistol.can_be_used_by(WeaponDefinition.EnemyRole.SCAVENGER), "Scavenger compatibility allows pistol")
	check(not chair.can_be_used_by(WeaponDefinition.EnemyRole.SCAVENGER), "Scavenger compatibility rejects heavy chair")
	check(chair.can_be_used_by(WeaponDefinition.EnemyRole.BRUTE), "Brute compatibility allows chair")
	check(not pistol.can_be_used_by(WeaponDefinition.EnemyRole.GRUNT), "Grunt cannot use weapons")
	# Exercise arena reset through the real input handler, including deferred replacement.
	player.set_mouse_captured(true)
	player.focus.set_active(true)
	key_action("restart")
	await frames(4)
	arena = current_scene
	player = arena.get_node("Player")
	check(get_nodes_in_group("world_items").size() == 10, "F5 recreates exactly ten physical objects")
	check(player.inventory.slots.all(func(item): return item == null), "F5 resets all five inventory slots")
	check(is_equal_approx(Engine.time_scale, 1.0), "F5 restores normal time when Shift is released")
	player.focus.set_active(true)
	arena.queue_free()
	await process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "scene teardown never leaks slow motion")
	print("MILESTONE RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
