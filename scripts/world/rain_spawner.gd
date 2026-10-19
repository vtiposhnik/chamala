class_name RainSpawner
extends Node3D

signal rain_spawned(count: int)
@export_range(1, 10) var object_count: int = 10
@export var spawn_seed: int = 7
@export var definitions: Array[WeaponDefinition] = []
@export var height: float = 5.5

func spawn_rain() -> void:
	if definitions.is_empty():
		return
	var random := RandomNumberGenerator.new()
	random.seed = spawn_seed
	for i in object_count:
		# A shuffled-looking spread, two of every type by default. No overlapping spawns.
		var definition := definitions[i % definitions.size()]
		var body := WorldItem.new()
		body.initialize(ItemInstance.new(definition))
		add_child(body)
		body.position = Vector3((i % 5 - 2) * 2.15, height + random.randf_range(0, 0.7), -float(i / 5) * 2.5)
		body.rotation = Vector3(random.randf_range(-0.4, 0.4), random.randf_range(-PI, PI), 0.2)
		body.angular_velocity = Vector3(random.randf_range(-1, 1), 0.4, random.randf_range(-1, 1))
	rain_spawned.emit(object_count)
