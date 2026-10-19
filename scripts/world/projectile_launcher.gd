class_name ProjectileLauncher
extends Node3D

@export var enabled: bool = false
@export var interval: float = 1.5
@export var projectile: ProjectileDefinition = preload("res://resources/test_projectile.tres")
@export var max_live_projectiles: int = 64
var remaining: float = 0.0
var placement: int = -1
var last_result: String = "idle"
var shots_fired: int = 0
var label: Label3D
@onready var player: RainPlayer = get_parent().get_node("Player")

func _ready() -> void:
	var visual := ItemVisual.new()
	add_child(visual)
	visual.box(Vector3(0.5, 0.4, 0.5), Vector3.ZERO, Color("ff9770"))
	visual.cylinder(0.08, 1.3, Vector3(0, -0.85, 0), Color("263442"))
	label = Label3D.new()
	label.position.y = 0.6
	label.font_size = 24
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	update_label()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_launcher"):
		enabled = not enabled
		remaining = interval # Allow time to prepare a defense after enabling.
		update_label()
	if event.is_action_pressed("move_launcher"):
		placement = (placement + 1) % 3
		place_relative_to_player()
	if event.is_action_pressed("fire_launcher"):
		fire()

func place_relative_to_player() -> void:
	var direction: Vector3 = [-player.global_basis.z, player.global_basis.x, player.global_basis.z][placement]
	for distance in [4.0, 3.5, 3.0, 2.5, 2.0]:
		var destination: Vector3 = player.camera.global_position + direction * distance
		destination.x = clampf(destination.x, -8.8, 8.8)
		destination.z = clampf(destination.z, -8.8, 8.8)
		destination.y = clampf(destination.y, 0.8, 7.0)
		if clear_muzzle(destination):
			global_position = destination
			break
	remaining = interval
	update_label()

func clear_muzzle(at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(projectile.radius + 0.02, 0.3)
	query.shape = sphere
	query.transform.origin = at
	query.collision_mask = projectile.hit_mask
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	remaining -= delta
	if remaining <= 0.0:
		remaining = maxf(interval, 0.05)
		fire()

func fire() -> PhysicalProjectile:
	if get_tree().get_nodes_in_group("projectiles").size() >= max_live_projectiles:
		return null
	if not clear_muzzle(global_position):
		last_result = "muzzle obstructed · K reposition"
		return null
	var shot := PhysicalProjectile.new()
	shot.data = projectile
	get_parent().add_child(shot)
	shot.global_position = global_position
	shot.resolved.connect(func(result: String, speed: float, damage: float):
		last_result = "%s · %.1f m/s · %.1f damage" % [result, speed, damage]
	)
	shot.launch((player.camera.global_position - global_position).normalized(), self)
	shots_fired += 1
	return shot

func update_label() -> void:
	label.text = "LAUNCHER · %s" % ("ON" if enabled else "OFF")
