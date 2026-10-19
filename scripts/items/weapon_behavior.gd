class_name WeaponBehavior
extends Node3D
## Reusable actions. Controller supplies the current user; definitions remain data-only.

signal action_requested(action: StringName, item: ItemInstance)
var item: ItemInstance
var actor: RainPlayer

func equip(instance: ItemInstance) -> void:
	item = instance

func unequip() -> void:
	item = null

func primary(_pressed: bool) -> void:
	pass

func secondary(_pressed: bool) -> void:
	pass

func tick(_delta: float) -> void:
	pass

func reload() -> void:
	pass

func cancel_action() -> void:
	pass

func status_text() -> String:
	return ""

func try_parry(_origin: Vector3, _projectile: RigidBody3D = null, _attacker: Node = null) -> bool:
	return false

func throw_action() -> void:
	if item != null:
		action_requested.emit(&"throw", item)
