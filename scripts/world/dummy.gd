extends StaticBody3D

@onready var health: Health = $Health
@onready var label: Label3D = $Status

func _ready() -> void:
	add_to_group("damageable")
	health.changed.connect(_on_health_changed)
	_on_health_changed(health.current, health.maximum)

func apply_damage(amount: float, direction: Vector3 = Vector3.ZERO, impulse: float = 0.0) -> void:
	health.apply_damage(amount, direction, impulse)

func _on_health_changed(current: float, maximum: float) -> void:
	label.text = "TEST DUMMY\n%03d / %03d" % [current, maximum]
	if current == 0.0:
		label.text = "TEST DUMMY\nOFFLINE"
