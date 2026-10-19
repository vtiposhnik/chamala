class_name ReleasePlacement
extends RefCounted
## Find a valid spawn, not a clear flight path. Only runs on a release attempt.
## Kept independent of launch strength so gentle placement can reuse it later.

static func find(actor: RainPlayer, data: WeaponDefinition, reach: float, margin: float) -> Dictionary:
	var space := actor.get_world_3d().direct_space_state
	var origin := actor.camera.global_position
	var forward := -actor.camera.global_basis.z
	var right := actor.camera.global_basis.x
	var basis := actor.global_basis.orthonormalized()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = data.create_world_shape()
	query.margin = margin
	query.transform = Transform3D(basis, origin)
	query.collision_mask = 1 | 4 | 8
	# Stop the release sweep just before the first obstacle. Flight after release
	# is still allowed to hit that obstacle with all environment collisions enabled.
	var starts_clear := space.intersect_shape(query, 1).is_empty()
	if starts_clear:
		query.motion = forward * reach
		var fraction := space.cast_motion(query)[0]
		var distance := maxf(0.0, reach * fraction - margin)
		var candidate := origin + forward * distance
		if valid_position(space, query, candidate):
			return {"transform": Transform3D(basis, candidate)}
	# If the forward gap is narrower than the prop + body, try a nearby hand/side
	# or overhead release. Exact shape checks admit heavy props without pretending
	# that every object is as large as its enclosing sphere.
	var side_reach := 0.32 + data.collision_size.x * 0.5 + margin * 2.0 + 0.06
	var offsets: Array[Vector3] = [right * side_reach, -right * side_reach,
		Vector3.UP * (0.35 + data.collision_size.y * 0.5 + margin * 2.0)]
	for offset in offsets:
		for adjustment in [0.15, 0.0, -0.2]:
			var candidate: Vector3 = origin + offset + forward * adjustment
			if origin.distance_to(candidate) > reach:
				continue
			if not valid_position(space, query, candidate):
				continue
			# Never teleport the object's center through a wall or another prop.
			var sight := PhysicsRayQueryParameters3D.create(origin, candidate, 1 | 4 | 8)
			if not space.intersect_ray(sight).is_empty():
				continue
			if starts_clear:
				query.transform.origin = origin
				query.motion = candidate - origin
				query.collision_mask = 1 | 4 | 8
				if space.cast_motion(query)[0] < 1.0:
					continue
			return {"transform": Transform3D(basis, candidate)}
	return {}

static func valid_position(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D, position: Vector3) -> bool:
	query.motion = Vector3.ZERO
	query.transform.origin = position
	query.collision_mask = 1 | 2 | 4 | 8 # Include the player: never spawn inside them.
	return space.intersect_shape(query, 1).is_empty()
