class_name WeaponBehavior
extends Node3D
## Future behavior interface. Combat deliberately remains inactive in milestone 01.

signal action_requested(action: StringName, item: ItemInstance)
var item: ItemInstance

func equip(instance: ItemInstance) -> void:
	item = instance

func unequip() -> void:
	item = null

func primary(_pressed: bool) -> void:
	pass

func secondary(_pressed: bool) -> void:
	pass

func throw_action() -> void:
	if item != null:
		action_requested.emit(&"throw", item)
