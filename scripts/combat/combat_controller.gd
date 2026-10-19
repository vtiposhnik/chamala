class_name CombatController
extends Node

const PISTOL = preload("res://scripts/combat/pistol_behavior.gd")
const PAN = preload("res://scripts/combat/pan_behavior.gd")
const BASEBALL = preload("res://scripts/combat/baseball_behavior.gd")

var actor: RainPlayer
var behavior: WeaponBehavior
var behaviors: Dictionary = {}
var primary_held: bool = false
@export_range(0.0, 0.5, 0.01) var switch_seconds: float = 0.1
var switch_remaining: float = 0.0
var throw_remaining: float = 0.0
var selected_item: ItemInstance

func _ready() -> void:
	actor = get_parent()
	for entry in [[WeaponDefinition.Kind.PISTOL, PISTOL], [WeaponDefinition.Kind.FRYING_PAN, PAN], [WeaponDefinition.Kind.BASEBALL, BASEBALL]]:
		var instance: WeaponBehavior = entry[1].new()
		instance.actor = actor
		add_child(instance)
		behaviors[entry[0]] = instance
	actor.get_node("Inventory").selection_changed.connect(_on_selection_changed)

func _physics_process(delta: float) -> void:
	var action_delta := actor.focus.action_delta(delta)
	# Preserve fractional tick time for held attacks (4.5 Hz is not an integer
	# number of 60 Hz ticks). No accumulated idle time or catch-up bursts.
	var carry := 0.0
	if selected_item != null and selected_item.attack_cooldown > 0.0:
		carry = maxf(0.0, action_delta - selected_item.attack_cooldown)
	switch_remaining = maxf(0.0, switch_remaining - action_delta)
	throw_remaining = maxf(0.0, throw_remaining - action_delta)
	for item in actor.inventory.slots:
		if item != null:
			item.attack_cooldown = maxf(0.0, item.attack_cooldown - action_delta)
			if item.attack_cooldown < 0.000001:
				item.attack_cooldown = 0.0
	if behavior != null:
		behavior.tick(action_delta)
		if primary_held and actor.mouse_captured and can_throw():
			var firing_item := selected_item
			behavior.primary(true)
			if firing_item != null and selected_item == firing_item and firing_item.attack_cooldown > 0.0:
				firing_item.attack_cooldown = maxf(0.0, firing_item.attack_cooldown - carry)

func _on_selection_changed(_index: int, item: ItemInstance) -> void:
	if selected_item == item:
		return
	cancel_action()
	selected_item = item
	switch_remaining = switch_seconds if item != null else 0.0
	if behavior != null:
		behavior.unequip()
	behavior = null
	if item != null:
		behavior = behaviors.get(item.definition.kind)
		if behavior != null:
			behavior.equip(item)

func primary(pressed: bool) -> void:
	primary_held = pressed
	if behavior != null and (not pressed or can_throw()):
		behavior.primary(pressed)

func secondary(pressed: bool) -> void:
	if behavior != null and can_throw():
		behavior.secondary(pressed)

func reload() -> void:
	if behavior != null and can_throw():
		behavior.reload()

func can_throw() -> bool:
	return switch_remaining <= 0.0 and throw_remaining <= 0.0

func begin_throw(recovery: float) -> void:
	throw_remaining = recovery

func cancel_action() -> void:
	primary_held = false
	if behavior != null:
		behavior.cancel_action()

func try_parry(origin: Vector3, projectile: RigidBody3D = null, attacker: Node = null) -> bool:
	return behavior.try_parry(origin, projectile, attacker) if behavior != null else false

func status_text() -> String:
	return behavior.status_text() if behavior != null else "F Throw"
