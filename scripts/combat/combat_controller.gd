class_name CombatController
extends Node

const PISTOL = preload("res://scripts/combat/pistol_behavior.gd")
const PAN = preload("res://scripts/combat/pan_behavior.gd")
const BASEBALL = preload("res://scripts/combat/baseball_behavior.gd")

var actor: RainPlayer
var behavior: WeaponBehavior
var behaviors: Dictionary = {}
var primary_held: bool = false

func _ready() -> void:
	actor = get_parent()
	for entry in [[WeaponDefinition.Kind.PISTOL, PISTOL], [WeaponDefinition.Kind.FRYING_PAN, PAN], [WeaponDefinition.Kind.BASEBALL, BASEBALL]]:
		var instance: WeaponBehavior = entry[1].new()
		instance.actor = actor
		add_child(instance)
		behaviors[entry[0]] = instance
	actor.get_node("Inventory").selection_changed.connect(_on_selection_changed)

func _physics_process(delta: float) -> void:
	for item in actor.inventory.slots:
		if item != null:
			item.attack_cooldown = maxf(0.0, item.attack_cooldown - delta)
	if behavior != null:
		behavior.tick(delta)
		if primary_held and actor.mouse_captured:
			behavior.primary(true)

func _on_selection_changed(_index: int, item: ItemInstance) -> void:
	cancel_action()
	if behavior != null:
		behavior.unequip()
	behavior = null
	if item != null:
		behavior = behaviors.get(item.definition.kind)
		if behavior != null:
			behavior.equip(item)

func primary(pressed: bool) -> void:
	primary_held = pressed
	if behavior != null:
		behavior.primary(pressed)

func secondary(pressed: bool) -> void:
	if behavior != null:
		behavior.secondary(pressed)

func reload() -> void:
	if behavior != null:
		behavior.reload()

func cancel_action() -> void:
	primary_held = false
	if behavior != null:
		behavior.cancel_action()

func try_parry(origin: Vector3, projectile: RigidBody3D = null, attacker: Node = null) -> bool:
	return behavior.try_parry(origin, projectile, attacker) if behavior != null else false

func status_text() -> String:
	return behavior.status_text() if behavior != null else "F Throw   ·   G Drop"
