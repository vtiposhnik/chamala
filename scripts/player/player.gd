class_name RainPlayer
extends CharacterBody3D

signal target_changed(target: WorldItem)
signal notice(message: String)
signal capture_changed(captured: bool)
signal hit_confirmed(damage: float)
signal parry_confirmed

@export var move_speed: float = 5.5
@export var acceleration: float = 24.0
@export var jump_speed: float = 5.0
@export var mouse_sensitivity: float = 0.0022
@export var pickup_distance: float = 3.4
@export var release_distance: float = 1.5
@export_range(0.005, 0.1, 0.005) var release_margin: float = 0.02
@export var throw_aim_distance: float = 50.0
@export_range(0.05, 0.5) var pickup_radius: float = 0.24
@export var push_force: float = 65.0
@export var push_response: float = 18.0

@onready var camera: Camera3D = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var inventory: Inventory = $Inventory
@onready var equipped: EquippedWeapon = $Head/Camera3D/WeaponMount
@onready var focus: FocusController = $Focus
@onready var combat: CombatController = $Combat
@onready var traversal: InertialMovement = $Traversal

var damage_taken: float = 0.0
var hits_received: int = 0
var blocks: int = 0

var target: WorldItem
var motion: Vector3 = Vector3.ZERO
var pitch: float = 0.0
var mouse_captured: bool = false

func _ready() -> void:
	inventory.selection_changed.connect(_on_selection_changed)
	set_mouse_captured(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_lab"):
		var scene := "res://scenes/arena.tscn" if get_tree().current_scene.has_method("respawn_player") else "res://scenes/traversal.tscn"
		get_tree().call_deferred("change_scene_to_file", scene)
		return
	if event.is_action_pressed("checkpoint_restart") and get_tree().current_scene.has_method("respawn_player"):
		get_tree().current_scene.respawn_player()
		return
	if event.is_action_pressed("release_mouse"):
		set_mouse_captured(not mouse_captured)
		get_viewport().set_input_as_handled()
		return
	if not mouse_captured:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			set_mouse_captured(true)
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45)
		head.rotation.x = pitch
	if event.is_action_pressed("pickup"):
		update_target()
		pick_up_target()
	if event.is_action_pressed("focus"):
		# Input policy is separate from the clock. A future hold option can call
		# set_active(event.pressed) here without changing any timing consumers.
		focus.toggle()
	if event.is_action_pressed("throw"):
		throw_selected()
	if event.is_action_pressed("primary"):
		combat.primary(true)
	if event.is_action_released("primary"):
		combat.primary(false)
	if event.is_action_pressed("secondary"):
		combat.secondary(true)
	if event.is_action_released("secondary"):
		combat.secondary(false)
	if event.is_action_pressed("reload"):
		combat.reload()
	if event.is_action_pressed("reset_dummy"):
		get_tree().call_group("test_dummies", "reset")
		reset_damage()
	if event.is_action_pressed("next_slot"):
		inventory.select(inventory.selected_index + 1)
	if event.is_action_pressed("previous_slot"):
		inventory.select(inventory.selected_index - 1)
	for index in Inventory.CAPACITY:
		if event.is_action_pressed("slot_%d" % (index + 1)):
			inventory.select(index)
	if event.is_action_pressed("restart"):
		get_tree().call_deferred("reload_current_scene")

func _physics_process(delta: float) -> void:
	var captured := mouse_captured
	var movement_delta := focus.movement_delta(delta)
	var movement_ratio := movement_delta / delta
	var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if captured else Vector2.ZERO
	var direction := global_basis * Vector3(axes.x, 0, axes.y)
	traversal.update_field(movement_delta)
	if traversal.airborne:
		traversal.integrate(axes, movement_delta)
		if captured and Input.is_action_just_pressed("jump"):
			traversal.try_push_off()
	else:
		motion.x = move_toward(motion.x, direction.x * move_speed, acceleration * movement_delta)
		motion.z = move_toward(motion.z, direction.z * move_speed, acceleration * movement_delta)
		if is_on_floor():
			motion.y = -0.1
			if captured and Input.is_action_just_pressed("jump"):
				motion.y = jump_speed
				traversal.airborne = traversal.gravity_multiplier < 0.999
		else:
			motion += GravityZone.acceleration_for(traversal.gravity_multiplier) * movement_delta
	var contact_velocity := motion * focus.movement_scale() if traversal.airborne else direction * move_speed * focus.movement_scale()
	velocity = motion * movement_ratio
	move_and_slide()
	motion = velocity / movement_ratio
	push_contacts(contact_velocity, delta, traversal.airborne)
	update_target()

func push_contacts(desired_velocity: Vector3, delta: float, allow_vertical: bool = false) -> void:
	var pushed: Dictionary = {}
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var body := collision.get_collider() as RigidBody3D
		if body == null or body.freeze or pushed.has(body.get_instance_id()):
			continue
		pushed[body.get_instance_id()] = true
		var normal := collision.get_normal()
		var direction := -normal if allow_vertical else Vector3(-normal.x, 0, -normal.z).normalized()
		if not allow_vertical and absf(normal.y) > 0.5:
			# The rounded character foot steps onto thin props. Push the leading
			# edge horizontally, but never a prop already directly under our feet.
			var offset := body.global_position - global_position
			offset.y = 0.0
			if offset.length() < 0.2 or offset.dot(desired_velocity) <= 0.0:
				continue
			direction = offset.normalized()
		# Never use the player's Focus-compensated velocity here (it can be 10x larger).
		var closing_speed := desired_velocity.dot(direction) - body.linear_velocity.dot(direction)
		if closing_speed <= 0.05:
			continue
		var impulse := minf(minf(closing_speed * push_response, push_force) * delta, body.mass * closing_speed)
		body.sleeping = false
		body.apply_central_impulse(direction * impulse)

func set_mouse_captured(value: bool) -> void:
	mouse_captured = value
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
	if not value:
		focus.set_active(false)
		combat.cancel_action()
		equipped.cancel_animation()
	capture_changed.emit(value)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		set_mouse_captured(false)

func update_target() -> void:
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * pickup_distance, 1 | 4 | 8)
	var hit := space.intersect_ray(query)
	var next: WorldItem = null
	if not hit.is_empty() and hit.collider is WorldItem and hit.collider.can_pick_up():
		next = hit.collider
	else:
		# A capsule is the swept volume of a camera-centered sphere. Query only this
		# narrow volume, then test at most four candidates for crosshair angle and LOS.
		var capsule := CapsuleShape3D.new()
		capsule.radius = pickup_radius
		capsule.height = pickup_distance + pickup_radius * 2.0
		var broad := PhysicsShapeQueryParameters3D.new()
		broad.shape = capsule
		broad.transform = Transform3D(Basis(Quaternion(Vector3.UP, forward)), origin + forward * pickup_distance * 0.5)
		broad.collision_mask = 4
		var candidates: Array[Dictionary] = []
		for result in space.intersect_shape(broad, 12):
			var body := result.collider as WorldItem
			if body == null or not body.can_pick_up():
				continue
			var offset := body.global_position - origin
			var along := offset.dot(forward)
			if along < 0.1 or offset.length() > pickup_distance:
				continue
			candidates.append({"body": body, "score": (offset - forward * along).length_squared() / (along * along)})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.score < b.score)
		for index in mini(candidates.size(), 4):
			var body: WorldItem = candidates[index].body
			var sight := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, body.global_position, 1 | 4 | 8))
			if not sight.is_empty() and sight.collider == body:
				next = body
				break
	if is_instance_valid(target) and target != next:
		target.set_highlighted(false)
	target = next
	if is_instance_valid(target):
		target.set_highlighted(true)
	target_changed.emit(target)

func pick_up_target() -> bool:
	if not is_instance_valid(target) or not target.can_pick_up():
		return false
	if inventory.is_full():
		notice.emit("Inventory full · press F to throw your selected object")
		return false
	var instance := target.claim()
	if instance == null:
		return false
	# No asynchronous gap between capacity check, claim, and insertion.
	inventory.add_item(instance)
	notice.emit("Collected " + instance.definition.display_name)
	target = null
	target_changed.emit(null)
	return true

func throw_selected(power: float = 1.0, underhand: bool = false) -> bool:
	var instance := inventory.current_item()
	if instance == null:
		notice.emit("Empty slot · look at an object and press E")
		return false
	if not instance.definition.has_capability(WeaponDefinition.Capability.THROWABLE) or not combat.can_throw():
		return false
	var forward := -camera.global_basis.z
	var placement := ReleasePlacement.find(self, instance.definition, release_distance, release_margin)
	if placement.is_empty():
		notice.emit("No safe release position · weapon kept")
		return false
	# Side releases converge on the camera's aim instead of shooting a parallel
	# path that misses a nearby prop. This does not bypass any physical collisions.
	var origin := camera.global_position
	var aim := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + forward * throw_aim_distance, 1 | 4 | 8))
	var aim_point: Vector3 = aim.position if not aim.is_empty() else origin + forward * throw_aim_distance
	var toward_aim: Vector3 = aim_point - placement.transform.origin
	if toward_aim.dot(forward) > release_margin:
		forward = toward_aim.normalized()
	var body := WorldItem.new()
	body.initialize(instance)
	get_tree().current_scene.get_node("Objects").add_child(body)
	body.global_transform = placement.transform
	body.interaction_delay = 0.25
	var direction := (forward + Vector3.UP * 0.35).normalized() if underhand else forward
	var inherited := motion * traversal.throw_inheritance if traversal.airborne or traversal.gravity_multiplier < 0.999 else Vector3.ZERO
	body.launch(direction, clampf(power, 0.1, 1.0), self, inherited)
	body.damage_reported.connect(confirm_hit)
	instance.attack_cooldown = maxf(instance.attack_cooldown, instance.definition.throw_recovery)
	inventory.remove_selected()
	combat.begin_throw(instance.definition.throw_recovery)
	notice.emit("Threw " + instance.definition.display_name)
	return true

func confirm_hit(damage: float) -> void:
	if damage > 0.0:
		hit_confirmed.emit(damage)

func _on_selection_changed(_index: int, instance: ItemInstance) -> void:
	if equipped.item == instance:
		return
	if instance == null:
		equipped.unequip()
	else:
		equipped.equip(instance)
		equipped.animate_action(&"switch", combat.switch_seconds)

# A resettable test damage counter, not a death/lives system.
func apply_damage(amount: float, _direction: Vector3 = Vector3.ZERO, _impulse: float = 0.0) -> float:
	if amount <= 0.0:
		return 0.0
	damage_taken += amount
	hits_received += 1
	notice.emit("HIT · %.1f damage · T resets test counters" % amount)
	return amount

func reset_damage() -> void:
	damage_taken = 0.0
	hits_received = 0
	blocks = 0
