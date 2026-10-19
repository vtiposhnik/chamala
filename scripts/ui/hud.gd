extends CanvasLayer

var player: RainPlayer
var slot_labels: Array[Label] = []
var slot_panels: Array[PanelContainer] = []
var prompt: Label
var status: Label
var toast: Label
var capture_hint: Label
var toast_time: float = 0.0
var crosshair: Label
var weapon_status: Label
var debug_info: Label
var hit_marker: Label
var hit_time: float = 0.0
const MINT := Color("80f3cd")

func _ready() -> void:
	layer = 2 # Above the dedicated held-weapon pass.
	player = get_parent().get_node("Player")
	var root := Control.new()
	root.name = "Layout"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := label("OBJECT / RAIN", 26, Color("e4eaf0"))
	title.position = Vector2(32, 25)
	root.add_child(title)
	var subtitle := label("PHYSICS + COMBAT     /     ITERATION 02", 12, Color("9aabba"))
	subtitle.position = Vector2(34, 61)
	root.add_child(subtitle)
	status = label("●  REAL TIME", 18, MINT)
	status.name = "FocusStatus"
	root.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.offset_left = -245
	status.offset_right = -35
	status.offset_top = 32
	status.offset_bottom = 60
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crosshair = label("+", 24, Color("effff9"))
	crosshair.name = "Crosshair"
	root.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -8
	crosshair.offset_right = 8
	crosshair.offset_top = -17
	crosshair.offset_bottom = 17
	prompt = centered(root, 50, 19)
	toast = centered(root, 85, 16)
	toast.modulate = Color("80f3cd")
	capture_hint = centered(root, -90, 22)
	capture_hint.text = "MOUSE RELEASED · click to resume"
	capture_hint.visible = not player.mouse_captured
	weapon_status = centered(root, 146, 16)
	debug_info = label("", 14, Color("9aabba"))
	debug_info.position = Vector2(34, 91)
	root.add_child(debug_info)
	hit_marker = centered(root, -52, 22)
	hit_marker.modulate = Color("ffe0a0")
	var inventory_row := HBoxContainer.new()
	inventory_row.name = "InventorySlots"
	root.add_child(inventory_row)
	inventory_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	inventory_row.offset_left = -370
	inventory_row.offset_right = 370
	inventory_row.offset_top = -127
	inventory_row.offset_bottom = -57
	inventory_row.add_theme_constant_override("separation", 10)
	for index in Inventory.CAPACITY:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(140, 70)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inventory_row.add_child(panel)
		var text := label("", 15, Color.WHITE)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(text)
		slot_labels.append(text)
		slot_panels.append(panel)
	var help := label("WASD / SPACE Move     E Pick up     G Drop     F Throw     1–5 / WHEEL Equip     SHIFT Focus     R Reload     T Dummy     F5 Reset     ESC Mouse", 13, Color("a6b6c4"))
	root.add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.offset_left = -600
	help.offset_right = 600
	help.offset_top = -39
	help.offset_bottom = -15
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player.inventory.changed.connect(refresh_inventory)
	player.inventory.selection_changed.connect(func(_i: int, _item: ItemInstance): refresh_inventory())
	player.target_changed.connect(show_target)
	player.notice.connect(show_notice)
	player.focus.changed.connect(show_focus)
	player.capture_changed.connect(func(captured: bool): capture_hint.visible = not captured)
	player.hit_confirmed.connect(func(damage: float):
		hit_marker.text = "×  %.1f" % damage
		hit_time = 0.25
	)
	player.parry_confirmed.connect(func():
		hit_marker.text = "◇  PARRY"
		hit_time = 0.35
	)
	refresh_inventory()
	show_notice("Ten objects. Five slots. Hold Shift to catch the rain.")

func label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	node.add_theme_constant_override("shadow_offset_y", 2)
	return node

func centered(root: Control, y: float, font_size: int) -> Label:
	var node := label("", font_size, Color("e0eaf2"))
	root.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	node.offset_left = -450
	node.offset_right = 450
	node.offset_top = y
	node.offset_bottom = y + 32
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node

func refresh_inventory() -> void:
	for index in Inventory.CAPACITY:
		var item := player.inventory.slots[index]
		var selected := index == player.inventory.selected_index
		slot_labels[index].text = "%d    %s\n%s" % [index + 1, "●" if selected else "", item.definition.display_name if item != null else "— empty —"]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("18362f") if selected else Color("14212ee8")
		style.border_color = MINT if selected else Color("3c4e60")
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(6)
		slot_panels[index].add_theme_stylebox_override("panel", style)

func show_target(target: WorldItem) -> void:
	if is_instance_valid(target):
		prompt.text = "%s  ·  %s" % [target.item.definition.display_name, "Inventory full" if player.inventory.is_full() else "[E] Pick up"]
		crosshair.modulate = MINT
	else:
		prompt.text = ""
		crosshair.modulate = Color.WHITE

func show_focus(active: bool) -> void:
	status.text = "●  FOCUS / %02d%%" % int(player.focus.slow_multiplier * 100) if active else "●  REAL TIME"
	status.modulate = Color("ffe0a0") if active else Color.WHITE

func show_notice(message: String) -> void:
	toast.text = message
	toast_time = 3.0

func _process(delta: float) -> void:
	toast_time = maxf(0.0, toast_time - delta / Engine.time_scale)
	toast.visible = toast_time > 0.0
	hit_time = maxf(0.0, hit_time - delta / Engine.time_scale)
	hit_marker.visible = hit_time > 0.0
	weapon_status.text = player.combat.status_text() if player.inventory.current_item() != null else ""
	if is_instance_valid(player.target):
		debug_info.text = "TARGET  %.3f kg   |   %.2f m/s" % [player.target.mass, player.target.linear_velocity.length()]
	elif player.inventory.current_item() != null:
		debug_info.text = "HELD  %.3f kg" % player.inventory.current_item().definition.mass
	else:
		debug_info.text = ""
