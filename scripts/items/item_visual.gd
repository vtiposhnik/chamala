class_name ItemVisual
extends Node3D
## Cheap primitive silhouettes shared by world and first-person representations.

var materials: Array[StandardMaterial3D] = []
var base_colors: Array[Color] = []

func build(data: WeaponDefinition) -> void:
	var dark := Color("263442")
	match data.kind:
		WeaponDefinition.Kind.PISTOL:
			box(Vector3(0.17, 0.16, 0.52), Vector3(0, 0.11, -0.08), data.color)
			box(Vector3(0.14, 0.28, 0.15), Vector3(0, -0.08, 0.1), dark)
			box(Vector3(0.06, 0.05, 0.06), Vector3(0, 0.21, -0.24), Color("b9fff0"))
		WeaponDefinition.Kind.FRYING_PAN:
			cylinder(0.29, 0.075, Vector3(0, 0, -0.17), data.color)
			cylinder(0.24, 0.08, Vector3(0, 0.018, -0.17), dark)
			box(Vector3(0.105, 0.075, 0.42), Vector3(0, 0, 0.28), data.color)
		WeaponDefinition.Kind.CHAIR:
			box(Vector3(0.64, 0.12, 0.64), Vector3(0, 0, 0), data.color)
			box(Vector3(0.64, 0.55, 0.09), Vector3(0, 0.31, 0.27), data.color)
			for x in [-0.25, 0.25]:
				for z in [-0.25, 0.25]:
					box(Vector3(0.07, 0.5, 0.07), Vector3(x, -0.3, z), dark)
		WeaponDefinition.Kind.UMBRELLA:
			cylinder(0.025, 1.05, Vector3.ZERO, dark)
			var canopy := CylinderMesh.new()
			canopy.top_radius = 0.025
			canopy.bottom_radius = 0.16
			canopy.height = 0.8
			canopy.radial_segments = 8
			part(canopy, Vector3(0, 0.12, 0), data.color)
			box(Vector3(0.14, 0.06, 0.06), Vector3(0.055, -0.53, 0), data.color)
		WeaponDefinition.Kind.BASEBALL:
			var ball := SphereMesh.new()
			ball.radius = 0.13
			ball.height = 0.26
			part(ball, Vector3.ZERO, data.color)
			var seam := TorusMesh.new()
			seam.inner_radius = 0.125
			seam.outer_radius = 0.134
			part(seam, Vector3.ZERO, Color("e97461"))

func box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	part(mesh, at, color)

func cylinder(radius: float, height: float, at: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	part(mesh, at, color)

func part(mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	node.material_override = material
	materials.append(material)
	base_colors.append(color)
	add_child(node)
	return node

func set_highlighted(value: bool) -> void:
	for i in materials.size():
		materials[i].emission_enabled = value
		materials[i].emission = Color("67f6ce")
		materials[i].emission_energy_multiplier = 0.65 if value else 0.0
		materials[i].albedo_color = base_colors[i].lerp(Color.WHITE, 0.3) if value else base_colors[i]
