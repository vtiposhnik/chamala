class_name WorldItem
extends RigidBody3D

signal claimed(item: ItemInstance)
signal damage_reported(amount: float)

var item: ItemInstance
var is_claimed: bool = false
var visual: ItemVisual
var interaction_delay: float = 0.0
var projectile_active: bool = false
var damage_limit: float = 0.0
var previous_velocity: Vector3 = Vector3.ZERO
var hit_targets: Dictionary = {}
var launch_owner: PhysicsBody3D
var owner_grace: float = 0.0
var reflection_pending: bool = false
var pending_impulse: Vector3 = Vector3.ZERO
var pending_torque: Vector3 = Vector3.ZERO
var flight_samples: Array[Vector3] = []
@onready var clock: FocusController = get_tree().get_first_node_in_group("focus_clock")

func initialize(instance: ItemInstance) -> void:
	item = instance
	name = String(item.definition.id)
	mass = item.definition.mass
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	continuous_cd = true
	linear_damp = 0.15
	angular_damp = 0.6
	contact_monitor = true
	max_contacts_reported = 4
	var material := PhysicsMaterial.new()
	material.bounce = item.definition.bounce
	material.friction = item.definition.friction
	physics_material_override = material
	var collider := CollisionShape3D.new()
	collider.shape = item.definition.create_world_shape()
	add_child(collider)
	visual = ItemVisual.new()
	visual.build(item.definition)
	add_child(visual)
	add_to_group("world_items")

func _physics_process(delta: float) -> void:
	interaction_delay = maxf(0.0, interaction_delay - (clock.real_delta(delta) if clock else delta))
	item.attack_cooldown = maxf(0.0, item.attack_cooldown - (clock.action_delta(delta) if clock else delta))
	if is_instance_valid(launch_owner):
		owner_grace = maxf(0.0, owner_grace - delta)
		var clearance := item.definition.collision_size.length() * 0.5 + 1.05
		if owner_grace == 0.0 and global_position.distance_to(launch_owner.global_position + Vector3.UP * 0.9) > clearance:
			clear_owner_exception()
	if sleeping:
		projectile_active = false

func launch(direction: Vector3, power: float, user: PhysicsBody3D, inherited_velocity: Vector3 = Vector3.ZERO) -> void:
	var data := item.definition
	sleeping = false
	var impulse := minf(data.throw_impulse * power, mass * data.throw_max_speed)
	# A newly added body's server-side mass is synchronized on its first physics
	# step. Queue the impulse for that step so every mass receives the right delta-v.
	pending_impulse = direction * impulse + inherited_velocity * mass
	# Torque is mass-scaled to avoid extreme spin on the lightest props.
	pending_torque = Vector3.RIGHT * mass * data.throw_spin * 0.05
	previous_velocity = direction * impulse / mass + inherited_velocity
	flight_samples.assign([previous_velocity])
	projectile_active = data.thrown_damage > 0.0
	damage_limit = data.thrown_damage * power
	hit_targets.clear()
	exclude_owner(user)

func exclude_owner(user: PhysicsBody3D) -> void:
	clear_owner_exception()
	launch_owner = user
	if is_instance_valid(user):
		add_collision_exception_with(user)
		user.add_collision_exception_with(self)
	owner_grace = item.definition.throw_grace_seconds

func clear_owner_exception() -> void:
	if is_instance_valid(launch_owner):
		remove_collision_exception_with(launch_owner)
		launch_owner.remove_collision_exception_with(self)
	launch_owner = null

func _exit_tree() -> void:
	clear_owner_exception()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not pending_impulse.is_zero_approx():
		state.apply_central_impulse(pending_impulse)
		state.apply_torque_impulse(pending_torque)
		pending_impulse = Vector3.ZERO
		pending_torque = Vector3.ZERO
	if projectile_active:
		for index in state.get_contact_count():
			var collider := state.get_contact_collider_object(index) as Node3D
			if collider == null:
				continue
			# Godot's "local" identifies this side of the contact; the reported
			# normal is already in world coordinates. Do not rotate it with ball spin.
			var normal := state.get_contact_local_normal(index)
			var speed := absf(previous_velocity.dot(normal))
			var incoming := previous_velocity
			# Godot CCD can clamp velocity for one or two steps *before* reporting
			# a contact. A short pre-contact history preserves actual approach speed.
			for sample in flight_samples:
				if absf(sample.dot(normal)) > speed:
					speed = absf(sample.dot(normal))
					incoming = sample
			if collider is RainPlayer and not reflection_pending and not hit_targets.has(collider.get_instance_id()) and speed >= item.definition.projectile_min_speed:
				reflection_pending = true
				hit_targets[collider.get_instance_id()] = true
				var damage := damage_limit * clampf(speed / item.definition.projectile_full_damage_speed, 0.0, 1.0)
				resolve_player_contact.call_deferred(collider, collider.camera.global_position - incoming.normalized(), damage, incoming.normalized())
			elif collider.has_method("apply_damage") and speed >= item.definition.projectile_min_speed and not hit_targets.has(collider.get_instance_id()):
				hit_targets[collider.get_instance_id()] = true
				var damage := damage_limit * clampf(speed / item.definition.projectile_full_damage_speed, 0.0, 1.0)
				resolve_impact.call_deferred(collider, damage, incoming.normalized())
	if state.get_contact_count() > 0:
		flight_samples.clear()
	flight_samples.append(state.linear_velocity)
	if flight_samples.size() > 3:
		flight_samples.pop_front()
	previous_velocity = state.linear_velocity

func resolve_impact(collider: Node3D, damage: float, direction: Vector3) -> void:
	if not is_instance_valid(collider) or is_claimed:
		return
	var applied := CombatHit.apply(collider, damage, direction, item.definition.impact_impulse)
	if applied > 0.0:
		if collider.has_method("stagger"):
			collider.stagger(item.definition.stagger_seconds)
		damage_reported.emit(applied)

func resolve_player_contact(player: RainPlayer, origin: Vector3, damage: float = 0.0, direction: Vector3 = Vector3.ZERO) -> void:
	reflection_pending = false
	if is_instance_valid(player):
		if not player.combat.defend_projectile(origin, self):
			player.apply_damage(damage, direction, item.definition.impact_impulse)

func can_reflect() -> bool:
	return projectile_active and not is_claimed and item.definition.deflectable

func can_block(categories: int) -> bool:
	return projectile_active and not is_claimed and (item.definition.projectile_category & categories) != 0

func block() -> void:
	# Recoverable objects fall away; disposable launcher projectiles are removed.
	projectile_active = false
	pending_impulse = Vector3.ZERO
	pending_torque = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	flight_samples.clear()

func reflect(direction: Vector3, user: PhysicsBody3D) -> void:
	sleeping = false
	pending_impulse = Vector3.ZERO
	pending_torque = Vector3.ZERO
	linear_velocity = direction.normalized() * maxf(previous_velocity.length(), 6.0)
	previous_velocity = linear_velocity
	flight_samples.assign([previous_velocity])
	hit_targets.clear()
	exclude_owner(user)

func can_pick_up() -> bool:
	return item.definition.has_capability(WeaponDefinition.Capability.RECOVERABLE) and not is_claimed and interaction_delay <= 0.0

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
