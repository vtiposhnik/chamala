class_name PhysicalProjectile
extends RigidBody3D
## Physical flight with a swept sphere guard ahead of the solver. CCD remains on;
## the sweep makes thin-wall hits and defensive interception deterministic at speed.

signal resolved(result: String, speed: float, damage: float)

var data: ProjectileDefinition
var source: Node3D
var launch_owner: PhysicsBody3D
var age: float = 0.0
var owner_grace: float = 0.0
var retired: bool = false
var previous_position: Vector3
var incoming_velocity: Vector3
var sphere: SphereShape3D

func _ready() -> void:
	if data == null:
		data = ProjectileDefinition.new()
	add_to_group("projectiles")
	mass = data.mass
	gravity_scale = data.gravity
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = 16
	collision_mask = data.hit_mask
	sphere = SphereShape3D.new()
	sphere.radius = data.radius
	var collision := CollisionShape3D.new()
	collision.shape = sphere
	add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = data.radius
	mesh.height = data.radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = data.color
	material.emission_enabled = true
	material.emission = data.color
	visual.material_override = material
	add_child(visual)
	body_entered.connect(func(body: Node):
		if not retired:
			resolve_contact.call_deferred(body, global_position)
	)

func launch(direction: Vector3, shooter: Node3D = null) -> void:
	source = shooter
	set_owner_exception(shooter as PhysicsBody3D)
	linear_velocity = direction.normalized() * data.speed
	incoming_velocity = linear_velocity
	previous_position = global_position

func _physics_process(delta: float) -> void:
	if retired:
		return
	age += delta
	if age >= data.lifetime or global_position.length() > 100.0:
		retire("expired", 0.0)
		return
	owner_grace = maxf(0.0, owner_grace - delta)
	if is_instance_valid(launch_owner) and owner_grace <= 0.0 and global_position.distance_to(CombatHit.center(launch_owner)) > 1.2:
		set_owner_exception(null)
	if linear_velocity.length_squared() > 0.01:
		incoming_velocity = linear_velocity
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.margin = 0.002
	query.collision_mask = data.hit_mask
	query.exclude = [get_rid()]
	if is_instance_valid(launch_owner):
		query.exclude.append(launch_owner.get_rid())
	query.transform.origin = previous_position
	var hits := space.intersect_shape(query, 1)
	var contact_position := previous_position
	if hits.is_empty():
		query.motion = global_position + linear_velocity * delta - previous_position
		var fractions := space.cast_motion(query)
		if fractions[0] < 1.0:
			contact_position = previous_position + query.motion * fractions[0]
			query.transform.origin = previous_position + query.motion * fractions[1]
			query.motion = Vector3.ZERO
			query.margin = 0.006
			hits = space.intersect_shape(query, 1)
	previous_position = global_position
	if not hits.is_empty():
		global_position = contact_position
		resolve_contact(hits[0].collider, contact_position)

func resolve_contact(body: Node, at: Vector3) -> void:
	if retired or not is_instance_valid(body) or body == launch_owner:
		return
	var direction := incoming_velocity.normalized()
	if body is RainPlayer:
		# Use approach direction, not a CCD-clamped or already reflected velocity.
		if body.combat.defend_projectile(body.camera.global_position - direction, self):
			return
	var applied := 0.0
	if body is Node3D:
		applied = CombatHit.apply(body, data.damage, direction, data.impulse)
	if is_instance_valid(source) and source.has_method("confirm_hit"):
		source.confirm_hit(applied)
	global_position = at
	retire("hit" if applied > 0.0 else "obstacle", applied)

func can_block(categories: int) -> bool:
	return not retired and (data.category & categories) != 0

func block() -> void:
	retire("blocked", 0.0)

func can_reflect() -> bool:
	return not retired and data.deflectable

func reflect(direction: Vector3, user: PhysicsBody3D) -> void:
	source = user
	set_owner_exception(user)
	sleeping = false
	linear_velocity = direction.normalized() * maxf(incoming_velocity.length() * data.reflection_speed_multiplier, 1.0)
	incoming_velocity = linear_velocity
	previous_position = global_position
	resolved.emit("deflected", linear_velocity.length(), 0.0)

func set_owner_exception(body: PhysicsBody3D) -> void:
	if is_instance_valid(launch_owner):
		remove_collision_exception_with(launch_owner)
	launch_owner = body
	if is_instance_valid(body):
		add_collision_exception_with(body)
	owner_grace = 0.18

func retire(result: String, damage: float) -> void:
	if retired:
		return
	retired = true
	resolved.emit(result, incoming_velocity.length(), damage)
	hide()
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	queue_free()
