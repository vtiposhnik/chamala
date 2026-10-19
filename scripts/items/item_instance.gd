class_name ItemInstance
extends RefCounted
## One identity survives world -> inventory -> world transitions.

var definition: WeaponDefinition
var rounds: int

func _init(data: WeaponDefinition) -> void:
	definition = data
	rounds = data.magazine_size
