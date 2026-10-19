class_name EquippedWeapon
extends WeaponBehavior

var visual: ItemVisual
var view: SubViewport
var mount: Node3D
var flash: MeshInstance3D
var animation: StringName
var remaining: float = 0.0
var duration: float = 0.1
var charge: float = 0.0

func _ready() -> void:
	# An isolated transparent pass gives held objects their own depth buffer.
	# Arena walls can neither clip nor hide the model; it has no physical body.
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var container := SubViewportContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	layer.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = SubViewport.new()
	view.name = "ViewmodelViewport"
	view.transparent_bg = true
	view.own_world_3d = true
	view.handle_input_locally = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(view)
	var view_camera := Camera3D.new()
	view_camera.current = true
	view_camera.fov = (get_parent() as Camera3D).fov
	view_camera.near = 0.05
	view.add_child(view_camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	view.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.light_energy = 0.6
	light.shadow_enabled = false
	view.add_child(light)
	mount = Node3D.new()
	mount.transform = transform
	view.add_child(mount)
	flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.065
	flash_mesh.height = 0.13
	flash.mesh = flash_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffe799")
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = Vector3(0, 0.1, -0.34)
	flash.visible = false
	mount.add_child(flash)

func equip(instance: ItemInstance) -> void:
	unequip()
	super.equip(instance)
	if item == null:
		return
	visual = ItemVisual.new()
	visual.build(item.definition)
	visual.scale = Vector3.ONE * item.definition.equipped_scale
	mount.add_child(visual)
	for mesh in visual.get_children():
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func unequip() -> void:
	if is_instance_valid(visual):
		visual.get_parent().remove_child(visual)
		visual.queue_free()
	visual = null
	cancel_animation()
	super.unequip()

func animate_action(action: StringName, seconds: float) -> void:
	animation = action
	duration = maxf(seconds, 0.01)
	remaining = duration

func set_charge(fraction: float) -> void:
	charge = fraction

func cancel_animation() -> void:
	remaining = 0.0
	charge = 0.0
	if is_instance_valid(flash):
		flash.visible = false

func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	mount.transform = transform
	mount.position.z += charge * 0.16
	flash.visible = item != null and animation == &"shoot" and remaining > duration * 0.6
	if remaining > 0.0:
		var progress := 1.0 - remaining / duration
		var wave := sin(progress * PI)
		match animation:
			&"shoot":
				mount.position.z += (1.0 - progress) * 0.1
				mount.rotation.x += (1.0 - progress) * 0.12
			&"swing":
				mount.position.x -= wave * 0.3
				mount.rotation.z += wave * 1.0
			&"reload":
				mount.position.y -= wave * 0.22
				mount.rotation.z -= wave * 0.5
			&"parry", &"parry_success":
				mount.position.x -= 0.2
				mount.position.y += 0.15
				mount.rotation.x += PI * 0.45
	if is_instance_valid(visual):
		visual.set_highlighted(remaining > 0.0 and animation in [&"parry", &"parry_success"])
