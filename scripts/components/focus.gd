class_name FocusController
extends Node

signal changed(active: bool)
## Effective speeds relative to real time, not multipliers on scaled delta.
@export_range(0.02, 1.0, 0.01) var world_multiplier: float = 0.15
@export_range(0.1, 1.0, 0.01) var movement_multiplier: float = 0.75
@export_range(0.1, 1.0, 0.01) var action_multiplier: float = 0.8
@export_range(0.0, 1.0, 0.01) var transition_seconds: float = 0.18
var active: bool = false
var blend: float = 0.0

func _ready() -> void:
	add_to_group("focus_clock")
	# Godot snapshots time_scale at the start of each frame, including all its
	# physics ticks. Change it only AFTER gameplay/render consumers have run.
	process_priority = 10000

func real_delta(scaled_delta: float) -> float:
	return scaled_delta / maxf(Engine.time_scale, 0.02)

func movement_scale() -> float:
	return lerpf(1.0, movement_multiplier, smoothstep(0.0, 1.0, blend))

func action_scale() -> float:
	return lerpf(1.0, action_multiplier, smoothstep(0.0, 1.0, blend))

func movement_delta(scaled_delta: float) -> float:
	return real_delta(scaled_delta) * movement_scale()

func action_delta(scaled_delta: float) -> float:
	return real_delta(scaled_delta) * action_scale()

func toggle() -> void:
	set_active(not active)

func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	changed.emit(active)

func _process(delta: float) -> void:
	var target := 1.0 if active else 0.0
	blend = move_toward(blend, target, real_delta(delta) / transition_seconds) if transition_seconds > 0.0 else target
	Engine.time_scale = lerpf(1.0, world_multiplier, smoothstep(0.0, 1.0, blend))

func _exit_tree() -> void:
	Engine.time_scale = 1.0
