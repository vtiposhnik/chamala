extends StaticBody3D

@onready var health: Health = $Health
@onready var label: Label3D = $Status
@onready var body: MeshInstance3D = $Body
var flash_remaining: float = 0.0
var stagger_remaining: float = 0.0
var last_damage: float = 0.0
var feedback_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("damageable")
	health.changed.connect(_on_health_changed)
	feedback_material = body.mesh.material.duplicate()
	body.material_override = feedback_material
	_on_health_changed(health.current, health.maximum)

func apply_damage(amount: float, direction: Vector3 = Vector3.ZERO, impulse: float = 0.0) -> float:
	var applied := health.apply_damage(amount, direction, impulse)
	if applied > 0.0:
		last_damage = applied
		flash_remaining = 0.25
		stagger(minf(impulse * 0.03, 0.3))
	return applied

func stagger(duration: float) -> void:
	stagger_remaining = maxf(stagger_remaining, duration)

func reset() -> void:
	flash_remaining = 0.0
	stagger_remaining = 0.0
	last_damage = 0.0
	health.reset()

func _physics_process(delta: float) -> void:
	flash_remaining = maxf(0.0, flash_remaining - delta)
	stagger_remaining = maxf(0.0, stagger_remaining - delta)
	feedback_material.emission_enabled = flash_remaining > 0.0
	feedback_material.emission = Color("ffd47d")
	feedback_material.emission_energy_multiplier = 0.6
	body.rotation.z = sin(stagger_remaining * 35.0) * minf(stagger_remaining, 0.15)
	_on_health_changed(health.current, health.maximum)
	if flash_remaining > 0.0:
		label.text += "\n−%.1f" % last_damage
	elif stagger_remaining > 0.0:
		label.text += "\nSTAGGERED"

func _on_health_changed(current: float, maximum: float) -> void:
	label.text = "TEST DUMMY\n%03d / %03d" % [current, maximum]
	if current == 0.0:
		label.text = "TEST DUMMY\nOFFLINE · T Reset"
