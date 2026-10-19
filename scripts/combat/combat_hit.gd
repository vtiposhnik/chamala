class_name CombatHit
extends RefCounted
## Shared hit application and bounded queries for current and future weapon users.

static func center(body: Node3D) -> Vector3:
	for child in body.get_children():
		if child is CollisionShape3D:
			return child.global_position
	return body.global_position

static func apply(body: Node3D, damage: float, direction: Vector3, impulse: float) -> float:
	if body is RigidBody3D and not body.freeze:
		body.sleeping = false
		# Cap delta-v on very light items (notably baseballs).
		body.apply_central_impulse(direction * minf(impulse, body.mass * 15.0))
	if body.has_method("apply_damage"):
		var result = body.apply_damage(damage, direction, impulse)
		return damage if result == null else float(result)
	return 0.0

static func melee(actor: RainPlayer, damage: float, reach: float, arc: float, impulse: float) -> float:
	var origin := actor.camera.global_position
	var forward := -actor.camera.global_basis.z
	var sphere := SphereShape3D.new()
	sphere.radius = reach
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform.origin = origin
	query.collision_mask = 4 | 8
	var space := actor.get_world_3d().direct_space_state
	var total := 0.0
	var seen: Dictionary = {}
	for hit in space.intersect_shape(query, 24):
		var body: Node3D = hit.collider
		if seen.has(body.get_instance_id()):
			continue
		seen[body.get_instance_id()] = true
		var offset := center(body) - origin
		if offset.length() > reach + 0.15 or offset.normalized().dot(forward) < cos(deg_to_rad(arc * 0.5)):
			continue
		var ray := PhysicsRayQueryParameters3D.create(origin, center(body), 1 | 4 | 8)
		var sight := space.intersect_ray(ray)
		if not sight.is_empty() and sight.collider == body:
			total += apply(body, damage, forward, impulse)
	return total
