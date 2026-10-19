class_name FocusController
extends Node

signal changed(active: bool)
@export_range(0.02, 1.0, 0.01) var slow_multiplier: float = 0.1
var active: bool = false

func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	Engine.time_scale = slow_multiplier if active else 1.0
	changed.emit(active)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
