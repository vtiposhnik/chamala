extends SceneTree

var checks: int = 0
var failures: int = 0
var arena: Node3D
var player: RainPlayer
var dummy: StaticBody3D

class MeleeAttacker extends Node:
	var interrupted: bool = false
	func interrupt_attack() -> void:
		interrupted = true

func _initialize() -> void:
	create_timer(45.0, true, false, true).timeout.connect(func():
		push_error("Combat test timed out")
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

func action(name: String, pressed: bool = true) -> void:
	var event: InputEvent = InputMap.action_get_events(name)[0].duplicate()
	event.pressed = pressed
	player._unhandled_input(event)

func click(name: String) -> void:
	action(name)
	action(name, false)

func definition(id: String) -> WeaponDefinition:
	return load("res://resources/weapons/%s.tres" % id)

func give(id: String) -> ItemInstance:
	var item := ItemInstance.new(definition(id))
	player.inventory.add_item(item)
	await frames(10) # Allow the short, action-clock equip interval.
	return item

func body_at(id: String, at: Vector3) -> WorldItem:
	var body := WorldItem.new()
	body.initialize(ItemInstance.new(definition(id)))
	arena.get_node("Objects").add_child(body)
	body.global_position = at
	return body

func fixture() -> void:
	Input.action_release("focus")
	Input.action_release("move_forward")
	if is_instance_valid(arena):
		arena.queue_free()
		await process_frame
	arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	player = arena.get_node("Player")
	dummy = arena.get_node("Dummy")
	player.set_mouse_captured(true)
	player.set_physics_process(false)
	for body in get_nodes_in_group("world_items"):
		body.queue_free()
	await frames(2)
	player.global_position = Vector3(0, 0, -2)
	player.head.look_at(dummy.get_node("Body").global_position)

func run() -> void:
	await test_pushes()
	await test_targeting_and_viewmodel()
	await test_pistol()
	await test_pan()
	await test_throwing()
	arena.queue_free()
	await process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "combat scene teardown restores time")
	print("COMBAT RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_pushes() -> void:
	var distances: Dictionary = {}
	for id in ["baseball", "pistol", "frying_pan", "chair"]:
		await fixture()
		player.global_position = Vector3(6, 0, 5)
		player.head.rotation = Vector3.ZERO
		var body := body_at(id, Vector3(6, definition(id).collision_size.y * 0.5 + 0.02, 3.8))
		await frames(240)
		check(body.can_sleep and body.sleeping, id + " can settle and sleep normally")
		var start := body.global_position.z
		player.set_physics_process(true)
		Input.action_press("move_forward")
		await frames(70)
		Input.action_release("move_forward")
		distances[id] = start - body.global_position.z
		print("PUSH MEASUREMENT ", id, " displacement=", distances[id], " speed=", body.linear_velocity.length())
		check(distances[id] > 0.15, id + " moves when walked into after sleeping")
		check(body.linear_velocity.length() < 8.0 and body.global_position.y < 1.2, id + " stays stable under contact pushing")
	check(distances.chair < distances.pistol, "heavy high-friction chair resists more than pistol")

func test_targeting_and_viewmodel() -> void:
	await fixture()
	player.global_position = Vector3(0, 0, 6)
	player.head.rotation = Vector3.ZERO
	var ball := body_at("baseball", Vector3(0.22, 1.65, 3.5))
	ball.freeze = true
	var unrelated := body_at("baseball", Vector3(1.0, 1.65, 3.5))
	unrelated.freeze = true
	await frames(2)
	player.update_target()
	check(player.target == ball, "narrow forgiving query catches off-axis small ball")
	var centered := body_at("baseball", Vector3(0, 1.65, 3.0))
	centered.freeze = true
	await frames(2)
	player.update_target()
	check(player.target == centered, "exact crosshair target outranks nearby objects")
	centered.queue_free()
	ball.global_position = Vector3(0.22, 1.65, 10.3)
	player.global_position = Vector3(0, 0, 8)
	player.rotation.y = PI
	await frames(2)
	player.update_target()
	check(player.target == null, "forgiving targeting cannot reach through wall")
	var held := await give("chair")
	player.global_position = Vector3(0, 0, 9.35)
	player.set_physics_process(true)
	await frames(4)
	check(player.equipped.visible and player.equipped.visual.visible, "held chair remains visible against wall")
	check(player.equipped.view.world_3d != player.get_world_3d(), "viewmodel has independent world and depth buffer")
	check(player.equipped.view.size.x > 500, "held-weapon viewport follows screen dimensions")
	check(player.inventory.current_item() == held, "wall contact preserves item identity")

func test_pistol() -> void:
	await fixture()
	var pistol := await give("pistol")
	click("primary")
	check(dummy.health.current == 80.0 and pistol.rounds == 11, "pistol hitscan deals 20 and consumes one round")
	click("primary")
	check(dummy.health.current == 80.0 and pistol.rounds == 11, "pistol rejects shots during cooldown")
	await give("frying_pan")
	player.inventory.select(0)
	click("primary")
	check(pistol.rounds == 11, "slot switching cannot bypass pistol cooldown")
	await frames(22)
	click("primary")
	check(dummy.health.current == 60.0 and pistol.rounds == 10, "pistol can fire again at the configured firing interval")
	pistol.rounds = 0
	await frames(22)
	click("primary")
	check(dummy.health.current == 60.0, "empty pistol cannot shoot")
	click("reload")
	await frames(30)
	check(pistol.rounds == 0, "reload has a real duration")
	await frames(40)
	check(pistol.rounds == 12, "R refills 12-round magazine")
	pistol.rounds = 3
	click("reload")
	player.inventory.select(1)
	await frames(80)
	check(pistol.rounds == 3, "switching away cancels unfinished reload")
	player.inventory.select(0)
	player.focus.set_active(true)
	await frames(15)
	click("primary")
	await frames(12)
	click("primary")
	check(pistol.rounds == 2, "Focus stretches weapon cooldown in real time")
	await frames(10)
	click("primary")
	check(pistol.rounds == 1, "scaled cooldown eventually completes during Focus")
	player.focus.set_active(false)
	click("reset_dummy")
	check(dummy.health.current == 100.0, "T restores dummy health without resetting inventory")
	player.global_position = Vector3(0, 0, -5.4)
	player.head.look_at(dummy.get_node("Body").global_position)
	await frames(22)
	click("secondary")
	check(dummy.health.current == 88.0, "pistol whip deals close-range secondary damage")
	player.global_position = Vector3(0, 0, 5)
	player.head.rotation = Vector3.ZERO
	var prop := body_at("chair", Vector3(0, 1.65, 2))
	prop.gravity_scale = 0.0
	prop.sleeping = true
	await frames(40)
	click("primary")
	await frames(2)
	check(not prop.sleeping and prop.linear_velocity.z < -0.2, "hitscan wakes and impulses a rigid body")

func test_pan() -> void:
	await fixture()
	var pan := await give("frying_pan")
	player.global_position = Vector3(0, 0, -5.4)
	player.head.look_at(dummy.get_node("Body").global_position)
	await frames(2)
	click("primary")
	check(dummy.health.current == 75.0, "pan swing deals 25 damage in range")
	click("primary")
	check(dummy.health.current == 75.0, "pan cannot deal repeated damage during recovery")
	await frames(39)
	click("secondary")
	check(player.combat.behavior.parry_remaining > 0.24, "RMB opens a 0.25 second parry window")
	var attacker := MeleeAttacker.new()
	root.add_child(attacker)
	check(player.combat.try_parry(player.camera.global_position - player.camera.global_basis.z, null, attacker), "frontal melee can be parried")
	check(attacker.interrupted, "successful melee parry interrupts attacker through shared interface")
	check(not player.combat.try_parry(player.camera.global_position - player.camera.global_basis.z), "parry consumes its window on success")
	attacker.queue_free()
	await frames(39)
	click("secondary")
	check(not player.combat.try_parry(player.camera.global_position + player.camera.global_basis.z), "parry rejects attacks from behind")
	await frames(16)
	check(not player.combat.try_parry(player.camera.global_position - player.camera.global_basis.z), "parry rejects late attacks")
	await frames(24)
	click("secondary")
	var projectile := body_at("baseball", Vector3(5, 3, 2))
	projectile.launch(Vector3.BACK, 1.0, null)
	check(player.combat.try_parry(player.camera.global_position - player.camera.global_basis.z, projectile), "pan reflects eligible active projectile")
	check(projectile.linear_velocity.dot(-player.camera.global_basis.z) > 5.0, "reflected projectile travels away from parrying player")
	check(projectile.launch_owner == player, "reflection transfers temporary owner immunity")
	await frames(2)
	check(projectile.linear_velocity.dot(-player.camera.global_basis.z) > 5.0, "queued launch cannot overwrite reflected velocity on the next physics step")
	await frames(40)
	player.rotation.y = PI
	player.head.rotation = Vector3.ZERO
	click("primary")
	check(dummy.health.current == 75.0, "pan cannot hit a target behind the player")
	check(pan.definition.attacks_per_second == 2.0, "pan recovery uses requested 2 swings per second")
	player.global_position = Vector3(5, 0, 4)
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	await frames(39)
	click("secondary")
	var incoming := body_at("baseball", Vector3(5, 1.65, 2))
	incoming.launch(Vector3.BACK, 1.0, null)
	await frames(9)
	check(incoming.launch_owner == player and incoming.linear_velocity.z < -5.0, "physical incoming projectile contact triggers parry and reflection")
	await frames(39)
	player.focus.set_active(true)
	await frames(15)
	click("secondary")
	await frames(6)
	check(player.combat.behavior.parry_remaining > 0.14, "Focus uses the faster player-action clock for parry")
	check(player.combat.try_parry(player.camera.global_position - player.camera.global_basis.z), "frontal attack can be parried during Focus")
	player.focus.set_active(false)
	await frames(40)
	var prop := body_at("pistol", Vector3(5, 1.6, 2.5))
	prop.gravity_scale = 0.0
	await frames(2)
	click("primary")
	await frames(2)
	check(prop.linear_velocity.z < -1.0, "pan applies knockback to physical objects")

func test_throwing() -> void:
	await fixture()
	player.global_position = Vector3(0, 0, -2)
	player.head.rotation = Vector3.ZERO
	var ball := await give("baseball")
	action("primary")
	await frames(61)
	check(player.inventory.current_item() == ball and player.combat.behavior.charge_fraction() == 1.0, "held LMB charges baseball without consuming it")
	action("primary", false)
	check(player.inventory.current_item() == null, "release launches baseball and empties its slot")
	var projectile: WorldItem = get_nodes_in_group("world_items")[0]
	check(projectile.launch_owner == player and player in projectile.get_collision_exceptions(), "throw temporarily excludes owner collisions")
	check(projectile.item == ball, "throw preserves exact item identity")
	await frames(12)
	print("BASEBALL IMPACT health=", dummy.health.current, " velocity=", projectile.linear_velocity, " pos=", projectile.global_position)
	check(dummy.health.current < 77.0 and dummy.health.current >= 70.0, "full charged direct impact approaches the 30 damage cap")
	check(dummy.stagger_remaining > 0.0, "baseball impact staggers dummy")
	var health_after_hit: float = dummy.health.current
	await frames(240)
	check(dummy.health.current == health_after_hit, "one launch cannot repeatedly damage the same target")
	check(projectile.can_pick_up() and projectile.global_position.y > -0.1, "baseball remains recoverable above floor after impact")
	check(projectile.launch_owner == null, "owner exception expires after projectile separates")
	projectile.freeze = true
	projectile.global_position = player.camera.global_position - player.camera.global_basis.z * 2.0
	await frames(2)
	player.update_target()
	check(player.target == projectile and player.pick_up_target(), "landed baseball can be targeted and picked up again")
	check(player.inventory.current_item() == ball, "recovered baseball retains the original item instance")
	await fixture()
	var slower := body_at("baseball", Vector3(0, 1.2, -5))
	slower.launch(Vector3.FORWARD, 0.45, null)
	await frames(16)
	check(dummy.health.current < 100.0 and dummy.health.current > health_after_hit, "lower-speed projectile impact causes less damage")
	await fixture()
	player.global_position = Vector3(0, 0, 5)
	player.head.rotation = Vector3.ZERO
	await give("baseball")
	click("secondary")
	var toss: WorldItem = get_nodes_in_group("world_items")[0]
	await frames(2)
	check(toss.linear_velocity.length() > 2.0 and toss.linear_velocity.length() < 6.0, "underhand toss is gentler than charged throw")
	check(toss.linear_velocity.y > 0.0, "underhand toss has upward arc")
	var bounced := false
	var was_falling := false
	for i in 100:
		await frames(1)
		if toss.linear_velocity.y < -1.0:
			was_falling = true
		if was_falling and toss.linear_velocity.y > 1.0:
			bounced = true
	check(bounced, "baseball physically bounces off arena floor")
	await fixture()
	player.global_position = Vector3(0, 0, 6)
	player.head.rotation = Vector3.ZERO
	var chair := await give("chair")
	click("throw")
	var heavy: WorldItem = get_nodes_in_group("world_items")[0]
	await frames(2)
	check(heavy.item == chair and heavy.linear_velocity.z < -1.0 and heavy.linear_velocity.length() < 5.0, "generic throw uses a mass-dependent impulse for chair")
	check(player.inventory.current_item() == null, "generic throw is independent of primary/secondary behaviors")
	var retained := await give("baseball")
	player.global_position = Vector3(0, 0, 9)
	player.rotation.y = PI
	await frames(2)
	check(player.throw_selected() and player.inventory.current_item() == null, "nearby wall permits a safe physical throw")
	check(get_nodes_in_group("world_items").any(func(body): return body.item == retained), "wall throw retains object identity in the world")
	player.global_position = Vector3(0, 0, 6)
	player.rotation.y = 0
	var charging_ball := await give("baseball")
	player.focus.set_active(true)
	await frames(15)
	action("primary")
	await frames(60)
	check(player.combat.behavior.charge_fraction() > 0.78 and player.combat.behavior.charge_fraction() < 0.82, "baseball charge runs at 80 percent in Focus")
	player.set_mouse_captured(false)
	check(not player.combat.behavior.charging and player.inventory.current_item() == charging_ball, "mouse release cancels charge without losing the object")
