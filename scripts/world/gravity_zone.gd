class_name GravityZone
extends Area3D
## Box-shaped gravity field with a smooth spatial boundary. Area signals enroll
## rigid bodies; players and enrolled bodies sample the same field in their own clock.
## Native Area gravity is disabled so gravity is never applied twice.

@export var size: Vector3 = Vector3(8, 8, 12)
@export_range(0.0, 2.0, 0.01) var multiplier: float = 0.18
@export_range(0.0, 4.0, 0.05) var boundary_width: float = 1.0
@export_range(0.0, 2.0, 0.01) var drift_damping: float = 0.02

func _ready() -> void:
	add_to_group("gravity_zones")
	collision_layer = 0
	collision_mask = 2 | 4 | 16
	gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	add_child(collider)
	body_entered.connect(func(body: Node3D):
		if body is RigidBody3D:
			enroll.call_deferred(body)
	)

func enroll(body: RigidBody3D) -> void:
	if not is_instance_valid(body) or body.is_queued_for_deletion() or body.has_node("GravityResponse"):
		return
	var response := preload("res://scripts/components/gravity_response.gd").new()
	response.name = "GravityResponse"
	body.add_child(response)
	body.sleeping = false

func weight_at(point: Vector3) -> float:
	var inside := size * 0.5 - to_local(point).abs()
	var depth := minf(inside.x, minf(inside.y, inside.z))
	if depth <= 0.0:
		return 0.0
	return smoothstep(0.0, boundary_width, depth) if boundary_width > 0.0 else 1.0

static func sample(body: Node3D) -> Dictionary:
	var result := {"multiplier": 1.0, "weight": 0.0, "damping": 0.0}
	var point := CombatHit.center(body)
	var zones := body.get_tree().get_nodes_in_group("gravity_zones")
	zones.sort_custom(func(a: GravityZone, b: GravityZone): return a.priority < b.priority if a.priority != b.priority else a.get_instance_id() < b.get_instance_id())
	for zone: GravityZone in zones:
		if zone.is_queued_for_deletion():
			continue
		var weight := zone.weight_at(point)
		if weight > 0.0:
			# Feather higher-priority fields over the underlying field, not over
			# normal gravity; entering a nested zero-G pocket cannot spike gravity.
			result.multiplier = lerpf(result.multiplier, zone.multiplier, weight)
			result.weight = 1.0 - (1.0 - result.weight) * (1.0 - weight)
			result.damping = zone.drift_damping
	return result

static func acceleration_for(gravity_multiplier: float) -> Vector3:
	# Vector API leaves room for future directions; this iteration is down-only.
	return Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * gravity_multiplier
