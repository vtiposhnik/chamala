class_name ItemInstance
extends RefCounted
## One identity survives world -> inventory -> world transitions.

var definition: WeaponDefinition
var rounds: int
## Scaled world seconds; survives switching and transfer back into the world.
var attack_cooldown: float = 0.0

func _init(data: WeaponDefinition) -> void:
	definition = data
	rounds = data.magazine_size
