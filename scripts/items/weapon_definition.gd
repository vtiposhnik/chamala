class_name WeaponDefinition
extends Resource
## Shared, immutable design data. Mutable state belongs to ItemInstance.

enum Kind { PISTOL, FRYING_PAN, CHAIR, UMBRELLA, BASEBALL }
enum EnemyRole { GRUNT, SCAVENGER, BRUTE }
enum Capability { THROWABLE = 1, RECOVERABLE = 2, SHOOTABLE = 4, RELOADABLE = 8, DEFENSIVE = 16, DEFLECTING = 32, HEAVY = 64, BOUNCING = 128 }

@export var id: StringName
@export var display_name: String = "Object"
@export var kind: Kind = Kind.PISTOL
@export var color: Color = Color.WHITE
@export_range(0.05, 20.0) var mass: float = 1.0
@export var collision_size: Vector3 = Vector3.ONE
@export_range(0.0, 1.0) var bounce: float = 0.15
@export_range(0.0, 1.0) var friction: float = 0.7
@export var equipped_scale: float = 0.65
@export var compatible_roles: Array[EnemyRole] = []
@export_flags("Throwable", "Recoverable", "Shootable", "Reloadable", "Defensive", "Deflecting", "Heavy / two-handed", "Bouncing") var capabilities: int = 3

@export_group("Combat")
@export var primary_damage: float = 20.0
@export var attacks_per_second: float = 3.0
@export var magazine_size: int = 0
@export var impact_impulse: float = 5.0
@export var melee_range: float = 2.0
@export var sweep_arc_degrees: float = 90.0
@export var parry_window: float = 0.25
@export var block_half_angle_degrees: float = 55.0
@export var charge_seconds: float = 1.0
@export var reload_seconds: float = 1.1
@export var secondary_damage: float = 12.0
@export var secondary_recovery: float = 0.5
@export var hitscan_range: float = 60.0
@export var projectile_min_speed: float = 2.0
@export var projectile_full_damage_speed: float = 24.0
@export var stagger_seconds: float = 0.35
@export var shield_open_seconds: float = 0.12
@export_flags("Standard", "Heavy") var blockable_categories: int = 1

@export_group("Physical throwing")
@export var throw_impulse: float = 14.0
@export var throw_max_speed: float = 20.0
@export var throw_spin: float = 3.0
@export var throw_grace_seconds: float = 0.18
@export var throw_recovery: float = 0.22
@export var thrown_damage: float = 0.0
@export_flags("Standard", "Heavy") var projectile_category: int = 1
@export var deflectable: bool = true

func has_capability(capability: Capability) -> bool:
	return (capabilities & capability) != 0

func create_world_shape() -> Shape3D:
	if kind == Kind.BASEBALL:
		var sphere := SphereShape3D.new()
		sphere.radius = collision_size.x * 0.5
		return sphere
	var box := BoxShape3D.new()
	box.size = collision_size
	return box

func can_be_used_by(role: EnemyRole) -> bool:
	return role in compatible_roles
