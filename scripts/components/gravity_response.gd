extends Node
## Restores each body's original settings outside fields, without touching velocity.

var body: RigidBody3D
var base_gravity: float
var base_damping: float
var base_damp_mode: int
var normal_total_damping: float

func _ready() -> void:
	body = get_parent()
	process_physics_priority = -100
	base_gravity = body.gravity_scale
	base_damping = body.linear_damp
	base_damp_mode = body.linear_damp_mode
	normal_total_damping = base_damping
	if base_damp_mode == RigidBody3D.DAMP_MODE_COMBINE:
		normal_total_damping += float(ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))

func _physics_process(_delta: float) -> void:
	var field := GravityZone.sample(body)
	var next_gravity: float = base_gravity * field.multiplier
	if not is_equal_approx(body.gravity_scale, next_gravity):
		body.sleeping = false
	body.gravity_scale = next_gravity
	if field.weight > 0.0:
		body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		body.linear_damp = lerpf(normal_total_damping, minf(normal_total_damping, field.damping), field.weight)
	else:
		body.linear_damp_mode = base_damp_mode
		body.linear_damp = base_damping
