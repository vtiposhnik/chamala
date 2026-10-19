class_name RainPlayer
extends CharacterBody3D

signal target_changed(target: WorldItem)
signal notice(message: String)
signal capture_changed(captured: bool)

@export var move_speed: float = 5.5
@export var acceleration: float = 24.0
@export var jump_speed: float = 5.0
@export var mouse_sensitivity: float = 0.0022
@export var pickup_distance: float = 3.4
@export var drop_distance: float = 1.5

@onready var camera: Camera3D = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var inventory: Inventory = $Inventory
@onready var equipped: EquippedWeapon = $Head/Camera3D/WeaponMount
@onready var focus: FocusController = $Focus

var target: WorldItem
var motion: Vector3 = Vector3.ZERO
var pitch: float = 0.0
var mouse_captured: bool = false

func _ready() -> void:
	inventory.selection_changed.connect(_on_selection_changed)
	set_mouse_captured(true)

func _unhandled_input(event: InputEvent) -> void:
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
	if event.is_action_pressed("drop"):
		drop_selected()
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
	# Focus scales the world clock. Character displacement and camera stay on real time.
	# delta was generated at the OLD scale; change Focus only after this movement tick.
	var time_scale := Engine.time_scale
	var real_delta := delta / time_scale
	var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if captured else Vector2.ZERO
	var direction := global_basis * Vector3(axes.x, 0, axes.y)
	motion.x = move_toward(motion.x, direction.x * move_speed, acceleration * real_delta)
	motion.z = move_toward(motion.z, direction.z * move_speed, acceleration * real_delta)
	if is_on_floor():
		motion.y = -0.1
		if captured and Input.is_action_just_pressed("jump"):
			motion.y = jump_speed
	else:
		motion.y -= 9.8 * real_delta
	velocity = motion / time_scale
	move_and_slide()
	motion = velocity * time_scale
	update_target()
	# Avoid a held model visibly passing through nearby arena walls or the dummy.
	var wall_query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 1.0, 1 | 8)
	equipped.visible = get_world_3d().direct_space_state.intersect_ray(wall_query).is_empty()
	focus.set_active(captured and Input.is_action_pressed("focus"))

func set_mouse_captured(value: bool) -> void:
	mouse_captured = value
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
	if not value:
		focus.set_active(false)
	capture_changed.emit(value)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		set_mouse_captured(false)

func update_target() -> void:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * pickup_distance, 1 | 4 | 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var next: WorldItem = null
	if not hit.is_empty() and hit.collider is WorldItem and hit.collider.can_pick_up():
		next = hit.collider
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
		notice.emit("Inventory full · press G to drop your selected object")
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

func drop_selected() -> bool:
	var instance := inventory.current_item()
	if instance == null:
		notice.emit("Empty slot · look at an object and press E")
		return false
	var forward := -camera.global_basis.z
	var origin := camera.global_position
	var destination := origin + forward * drop_distance
	# Sweep a conservative enclosing sphere. A wall, floor, dummy or item blocks the drop.
	var sphere := SphereShape3D.new()
	sphere.radius = instance.definition.collision_size.length() * 0.5 + 0.04
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = destination - origin
	query.collision_mask = 1 | 4 | 8
	var space := get_world_3d().direct_space_state
	var fractions := space.cast_motion(query)
	var blocked := not space.intersect_shape(query, 1).is_empty() or (not fractions.is_empty() and fractions[0] < 1.0)
	query.transform.origin = destination
	query.motion = Vector3.ZERO
	blocked = blocked or not space.intersect_shape(query, 1).is_empty()
	if blocked:
		notice.emit("Make a little room to drop · look ahead into clear space")
		return false
	var body := WorldItem.new()
	body.initialize(instance)
	get_tree().current_scene.get_node("Objects").add_child(body)
	body.global_position = destination
	body.rotation.y = rotation.y
	body.interaction_delay = 0.25
	body.linear_velocity = forward * 1.2
	inventory.remove_selected()
	notice.emit("Dropped " + instance.definition.display_name)
	return true

func _on_selection_changed(_index: int, instance: ItemInstance) -> void:
	if instance == null:
		equipped.unequip()
	else:
		equipped.equip(instance)
