extends WeaponBehavior

var parry_remaining: float = 0.0

func primary(pressed: bool) -> void:
	if not pressed or item == null or item.attack_cooldown > 0.0:
		return
	item.attack_cooldown = 1.0 / item.definition.attacks_per_second
	actor.confirm_hit(CombatHit.melee(actor, item.definition.primary_damage, item.definition.melee_range, item.definition.sweep_arc_degrees, item.definition.impact_impulse))
	actor.equipped.animate_action(&"swing", 0.3)

func secondary(pressed: bool) -> void:
	if not pressed or item == null or item.attack_cooldown > 0.0:
		return
	parry_remaining = item.definition.parry_window
	item.attack_cooldown = 1.0 / item.definition.attacks_per_second
	actor.equipped.animate_action(&"parry", parry_remaining)

func tick(delta: float) -> void:
	parry_remaining = maxf(0.0, parry_remaining - delta)

func try_parry(origin: Vector3, projectile: RigidBody3D = null, attacker: Node = null) -> bool:
	if item == null or parry_remaining <= 0.0:
		return false
	var toward_attack := (origin - actor.camera.global_position).normalized()
	if toward_attack.dot(-actor.camera.global_basis.z) < cos(deg_to_rad(item.definition.block_half_angle_degrees)):
		return false
	if projectile != null:
		if not projectile.has_method("can_reflect") or not projectile.can_reflect():
			return false
		projectile.reflect(-actor.camera.global_basis.z, actor)
	if attacker != null and attacker.has_method("interrupt_attack"):
		attacker.interrupt_attack()
	parry_remaining = 0.0
	actor.equipped.animate_action(&"parry_success", 0.18)
	actor.notice.emit("PARRY · attack interrupted")
	actor.parry_confirmed.emit()
	return true

func cancel_action() -> void:
	parry_remaining = 0.0

func unequip() -> void:
	cancel_action()
	super.unequip()

func status_text() -> String:
	return "PARRY ACTIVE" if parry_remaining > 0.0 else "LMB Swing   ·   RMB Timed parry"
