extends Node3D
## A contained experiment. The original arena remains available through F6.

@export var fall_height: float = -10.0
@export var start_checkpoint: Vector3 = Vector3(0, 0.1, 6)
@export var bridge_checkpoint: Vector3 = Vector3(0, 0.1, -22)
@export var destination_checkpoint: Vector3 = Vector3(0, 0.1, -40)
var checkpoint: Vector3
var checkpoint_stage: int = 0
var rescued_objects: int = 0
@onready var player: RainPlayer = $Player

func _ready() -> void:
	checkpoint = start_checkpoint
	# A: normal-gravity comparison platform.
	block("Start", Vector3(0, -0.25, 3), Vector3(10, 0.5, 10), Color("48535d"))
	# B: enclosed corridor, open at each end.
	block("CorridorFloor", Vector3(0, -0.25, -11), Vector3(8, 0.5, 18), Color("334b55"))
	block("CorridorCeiling", Vector3(0, 6.25, -11), Vector3(8, 0.5, 18), Color("334b55"))
	for x in [-4.25, 4.25]:
		block("CorridorWall", Vector3(x, 3, -11), Vector3(0.5, 6, 18), Color("415864"))
	block("PushPillar", Vector3(-2.3, 2.0, -6), Vector3(0.8, 4, 0.8), Color("9a8d72"))
	block("FloatingObstacle", Vector3(2.2, 3.0, -16), Vector3(1.1, 1.0, 1.1), Color("9a8d72"))
	# C: ten-metre gap. Backstop catches overshoots; there is no floor in the gap.
	block("Departure", Vector3(0, -0.25, -22), Vector3(8, 0.5, 4), Color("48535d"))
	block("Destination", Vector3(0, -0.25, -40), Vector3(10, 0.5, 12), Color("42685d"))
	block("DestinationBackstop", Vector3(0, 6, -46.25), Vector3(10, 12, 0.5), Color("48535d"))
	for x in [-5.25, 5.25]:
		block("DestinationSide", Vector3(x, 3, -40), Vector3(0.5, 6, 12), Color("48535d"))
	# Thin lines mark field entrances, not invisible solid barriers.
	for z in [-2.0, -20.0, -24.0, -34.0]:
		block("Threshold", Vector3(0, 0.015, z), Vector3(7.8, 0.03, 0.1), Color("80f3cd"), false)
	sign_at("A · NORMAL GRAVITY\nWASD Move · Space Jump · F6 Arena", Vector3(0, 3, 0))
	sign_at("B · LOW GRAVITY\nLook + WASD Steer · Space Push off", Vector3(0, 4.8, -5))
	sign_at("ZERO-G POCKET\nKeep momentum · steer sparingly", Vector3(0, 4.9, -13))
	sign_at("C · BROKEN BRIDGE\nRun + jump · Backspace Checkpoint", Vector3(0, 3.2, -23))
	sign_at("DESTINATION\nLand here to complete the crossing", Vector3(0, 4, -43))
	var kinds := ["pistol", "frying_pan", "chair", "umbrella", "baseball"]
	for i in kinds.size():
		spawn_prop(kinds[i], Vector3(-3 + i * 1.5, 1.4, 2), Vector3.ZERO)
		spawn_prop(kinds[i], Vector3(-2.6 + i * 1.3, 2.4 + (i % 2) * 0.8, -11.5), Vector3(0.15, 0, -0.1))
	spawn_prop("chair", Vector3(-2, 2.4, -27), Vector3(0.1, 0, 0))
	spawn_prop("baseball", Vector3(2, 3, -29), Vector3(-0.15, 0.1, 0))
	spawn_prop("umbrella", Vector3(1, 2.5, -31), Vector3(0, 0, 0.1))
	player.notice.emit("TRAVERSAL EXPERIMENT · F6 Arena · Backspace Checkpoint")

func block(title: String, at: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = title
	if solid:
		body.collision_layer = 1
		body.collision_mask = 2 | 4 | 16
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	var visual := ItemVisual.new()
	visual.box(size, Vector3.ZERO, color)
	body.add_child(visual)
	add_child(body)
	body.position = at

func sign_at(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.pixel_size = 0.008
	label.visibility_range_end = 10.0
	if text.begins_with("DESTINATION"):
		label.text = "DESTINATION"
		label.font_size = 64
		label.pixel_size = 0.012
		label.visibility_range_end = 60.0
	label.modulate = Color("80f3cd")
	add_child(label)
	label.position = at

func spawn_prop(id: String, at: Vector3, drift: Vector3) -> void:
	var body := WorldItem.new()
	body.initialize(ItemInstance.new(load("res://resources/weapons/%s.tres" % id)))
	$Objects.add_child(body)
	body.global_position = at
	body.linear_velocity = drift
	body.set_meta("lab_home", at)

func _physics_process(_delta: float) -> void:
	if player.global_position.y < fall_height:
		respawn_player()
	if player.is_on_floor() and absf(player.global_position.x) < 3.8:
		if checkpoint_stage == 0 and player.global_position.z < -20.5 and player.global_position.z > -24.0:
			checkpoint = bridge_checkpoint
			checkpoint_stage = 1
			player.notice.emit("BRIDGE CHECKPOINT · run and jump across")
		elif checkpoint_stage < 2 and player.global_position.z < -35.0:
			checkpoint = destination_checkpoint
			checkpoint_stage = 2
			player.notice.emit("CROSSING COMPLETE · F5 resets experiment · F6 Arena")
	# A fall should not permanently destroy one of the limited test objects.
	for body: WorldItem in get_tree().get_nodes_in_group("world_items"):
		if body.global_position.y < fall_height:
			var recovery := checkpoint + Vector3((rescued_objects % 5 - 2) * 1.2, 2.5 + (rescued_objects / 5 % 3) * 1.3, -1.5)
			# Keep the gap's comparison props available during long playtests.
			# Picked-up/thrown bodies have no home and return near the checkpoint.
			body.global_position = body.get_meta("lab_home", recovery)
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			body.pending_impulse = Vector3.ZERO
			body.pending_torque = Vector3.ZERO
			body.projectile_active = false
			body.flight_samples.clear()
			body.clear_owner_exception()
			body.sleeping = false
			rescued_objects += 1

func respawn_player() -> void:
	player.combat.cancel_action()
	player.equipped.cancel_animation()
	player.focus.set_active(false)
	player.global_position = checkpoint
	player.motion = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.traversal.reset()
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.pitch = 0.0
	player.notice.emit("CHECKPOINT · inventory kept · F5 resets everything")
