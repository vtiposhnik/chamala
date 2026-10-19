class_name WorldItem
extends RigidBody3D

signal claimed(item: ItemInstance)

var item: ItemInstance
var is_claimed: bool = false
var visual: ItemVisual
var interaction_delay: float = 0.0

func initialize(instance: ItemInstance) -> void:
	item = instance
	name = String(item.definition.id)
	mass = item.definition.mass
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	continuous_cd = true
	linear_damp = 0.15
	angular_damp = 0.6
	var material := PhysicsMaterial.new()
	material.bounce = item.definition.bounce
	material.friction = item.definition.friction
	physics_material_override = material
	var collider := CollisionShape3D.new()
	if item.definition.kind == WeaponDefinition.Kind.BASEBALL:
		var sphere := SphereShape3D.new()
		sphere.radius = item.definition.collision_size.x * 0.5
		collider.shape = sphere
	else:
		var box := BoxShape3D.new()
		box.size = item.definition.collision_size
		collider.shape = box
	add_child(collider)
	visual = ItemVisual.new()
	visual.build(item.definition)
	add_child(visual)
	add_to_group("world_items")

func _physics_process(delta: float) -> void:
	interaction_delay = maxf(0.0, interaction_delay - delta / Engine.time_scale)

func can_pick_up() -> bool:
	return not is_claimed and interaction_delay <= 0.0

func claim() -> ItemInstance:
	if not can_pick_up():
		return null
	is_claimed = true
	hide()
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	claimed.emit(item)
	queue_free()
	return item

func set_highlighted(value: bool) -> void:
	visual.set_highlighted(value and can_pick_up())
