class_name Health
extends Node

signal changed(current: float, maximum: float)
signal damaged(amount: float, direction: Vector3, impulse: float)
signal died

@export var maximum: float = 100.0
var current: float

func _ready() -> void:
	current = maximum

func apply_damage(amount: float, direction: Vector3 = Vector3.ZERO, impulse: float = 0.0) -> void:
	if current <= 0.0 or amount <= 0.0:
		return
	current = maxf(0.0, current - amount)
	damaged.emit(amount, direction, impulse)
	changed.emit(current, maximum)
	if current == 0.0:
		died.emit()

func reset() -> void:
	current = maximum
	changed.emit(current, maximum)
