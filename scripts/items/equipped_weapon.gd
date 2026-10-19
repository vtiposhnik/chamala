class_name EquippedWeapon
extends WeaponBehavior

var visual: ItemVisual

func equip(instance: ItemInstance) -> void:
	unequip()
	super.equip(instance)
	if item == null:
		return
	visual = ItemVisual.new()
	visual.build(item.definition)
	visual.scale = Vector3.ONE * item.definition.equipped_scale
	add_child(visual)

func unequip() -> void:
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
	visual = null
	super.unequip()
