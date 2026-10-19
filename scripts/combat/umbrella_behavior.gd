extends WeaponBehavior

var held: bool = false
var openness: float = 0.0

func primary(pressed: bool) -> void:
	held = pressed
	if not held:
		# Protection ends on release; the visual can finish closing afterward.
		actor.equipped.set_shield_open(openness)

func tick(delta: float) -> void:
	if item == null:
		return
	openness = move_toward(openness, 1.0 if held else 0.0, delta / maxf(item.definition.shield_open_seconds, 0.01))
	actor.equipped.set_shield_open(openness)

func try_block(origin: Vector3, projectile: RigidBody3D) -> bool:
	if item == null or not held or openness < 1.0:
		return false
	if not projectile.has_method("can_block") or not projectile.can_block(item.definition.blockable_categories):
		return false
	var toward_attack := (origin - actor.camera.global_position).normalized()
	if toward_attack.dot(-actor.camera.global_basis.z) < cos(deg_to_rad(item.definition.block_half_angle_degrees)):
		return false
	projectile.block()
	actor.equipped.animate_action(&"block", 0.18)
	actor.notice.emit("BLOCK · umbrella stopped projectile")
	actor.blocks += 1
	return true

func cancel_action() -> void:
	held = false
	openness = 0.0
	actor.equipped.set_shield_open(0.0)

func unequip() -> void:
	cancel_action()
	super.unequip()

func status_text() -> String:
	return "BLOCKING · %d° front · F Throw" % (item.definition.block_half_angle_degrees * 2.0) if held and openness >= 1.0 else "Hold LMB Open shield · F Throw"
