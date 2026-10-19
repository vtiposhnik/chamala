extends Node3D

func _ready() -> void:
	# Markings and labels are visual-only; structural collisions are explicit in the scene.
	var markings := ItemVisual.new()
	$Arena.add_child(markings)
	for x in range(-9, 10, 2):
		markings.box(Vector3(0.025, 0.006, 20), Vector3(x, 0.008, 0), Color("2a424d"))
	for z in range(-9, 10, 2):
		markings.box(Vector3(20, 0.006, 0.025), Vector3(0, 0.008, z), Color("2a424d"))
	markings.box(Vector3(10.5, 0.015, 0.08), Vector3(0, 0.016, 2), Color("80f3cd"))
	markings.box(Vector3(10.5, 0.015, 0.08), Vector3(0, 0.016, -4.5), Color("80f3cd"))
	for x in [-5.25, 5.25]:
		markings.box(Vector3(0.08, 0.015, 6.5), Vector3(x, 0.016, -1.25), Color("80f3cd"))
	var sign_label := Label3D.new()
	sign_label.text = "OBJECT / RAIN\nDROP LAB    —    01"
	sign_label.font_size = 80
	sign_label.pixel_size = 0.009
	sign_label.position = Vector3(0, 4.1, -9.72)
	sign_label.modulate = Color("80f3cd")
	$Arena.add_child(sign_label)
	$Objects.spawn_rain()
