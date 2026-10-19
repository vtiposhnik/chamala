class_name ProjectileDefinition
extends Resource
## Reusable attack data. Ownership and impact state live on each projectile.

@export var speed: float = 12.0
@export var damage: float = 10.0
@export var impulse: float = 3.0
@export var radius: float = 0.09
@export var mass: float = 0.1
@export var gravity: float = 0.0
@export var lifetime: float = 8.0
@export_flags_3d_physics var hit_mask: int = 15
@export_flags("Standard", "Heavy") var category: int = 1
@export var deflectable: bool = true
@export var reflection_speed_multiplier: float = 1.0
@export var color: Color = Color("ff9770")
