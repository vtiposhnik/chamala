class_name InertialMovement
extends Node
## Small movement extension; ordinary FPS acceleration stays in RainPlayer.

@export var air_acceleration: float = 2.5
@export var air_damping: float = 0.03
@export var controlled_speed: float = 6.0
@export var steering_reserve: float = 4.0
@export var push_speed: float = 5.0
@export var max_push_speed: float = 8.0
@export var push_cooldown: float = 0.35
@export var surface_reach: float = 0.65
@export var vertical_surface_reach: float = 1.05
@export var minimum_push_mass: float = 3.0
@export var object_reaction_impulse: float = 12.0
@export var object_reaction_speed_cap: float = 3.0
@export_range(0.0, 1.0, 0.05) var throw_inheritance: float = 0.65

var actor: RainPlayer
var airborne: bool = false
var gravity_multiplier: float = 1.0
var remaining_steering: float = 4.0
var push_remaining: float = 0.0

func _ready() -> void:
	actor = get_parent()
	remaining_steering = steering_reserve

func update_field(delta: float) -> void:
	gravity_multiplier = GravityZone.sample(actor).multiplier
	push_remaining = maxf(0.0, push_remaining - delta)
	if actor.is_on_floor():
		airborne = false
		remaining_steering = steering_reserve
	elif gravity_multiplier < 0.999:
		airborne = true
	# Retain a traversal jump's momentum when leaving a zone, until landing.

func integrate(axes: Vector2, delta: float) -> void:
	actor.motion *= exp(-air_damping * delta)
	var direction := actor.camera.global_basis * Vector3(axes.x, 0, axes.y)
	if not direction.is_zero_approx() and remaining_steering > 0.0:
		direction = direction.normalized()
		# Limit only player-added speed along the requested direction. Never clamp
		# externally acquired momentum, or instantly rotate the velocity vector.
		var addition := minf(air_acceleration * delta, remaining_steering)
		addition = minf(addition, maxf(0.0, controlled_speed - actor.motion.dot(direction)))
		actor.motion += direction * addition
		remaining_steering -= addition
	actor.motion += GravityZone.acceleration_for(gravity_multiplier) * delta

func try_push_off() -> bool:
	if push_remaining > 0.0 or not (airborne or gravity_multiplier < 0.999):
		return false
	var origin := CombatHit.center(actor)
	var directions: Array[Vector3] = [-actor.camera.global_basis.z, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.UP, Vector3.DOWN]
	var space := actor.get_world_3d().direct_space_state
	for direction in directions:
		var reach := vertical_surface_reach if absf(direction.y) > 0.9 else surface_reach
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * reach, 1 | 4)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var body: PhysicsBody3D = hit.collider
		if body is RigidBody3D and body.mass < minimum_push_mass:
			continue
		var normal: Vector3 = hit.normal
		var addition := minf(push_speed, maxf(0.0, max_push_speed - actor.motion.dot(normal)))
		if addition <= 0.0:
			continue
		actor.motion += normal * addition
		if body is RigidBody3D and not body.freeze:
			body.sleeping = false
			body.apply_central_impulse(-normal * minf(object_reaction_impulse, body.mass * object_reaction_speed_cap))
		push_remaining = push_cooldown
		remaining_steering = steering_reserve
		airborne = true
		actor.notice.emit("PUSH OFF · momentum gained")
		return true
	return false

func reset() -> void:
	airborne = false
	gravity_multiplier = 1.0
	remaining_steering = steering_reserve
	push_remaining = 0.0
