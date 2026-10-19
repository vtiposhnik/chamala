extends WeaponBehavior

var reload_remaining: float = 0.0

func primary(pressed: bool) -> void:
	if not pressed or item == null or item.attack_cooldown > 0.0 or reload_remaining > 0.0:
		return
	if item.rounds == 0:
		return
	var data := item.definition
	item.rounds -= 1
	item.attack_cooldown = 1.0 / data.attacks_per_second
	var direction := -actor.camera.global_basis.z
	var origin := actor.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * data.hitscan_range, 1 | 4 | 8)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		actor.confirm_hit(CombatHit.apply(hit.collider, data.primary_damage, direction, data.impact_impulse))
	actor.equipped.animate_action(&"shoot", 0.12)

func secondary(pressed: bool) -> void:
	if not pressed or item == null or reload_remaining > 0.0 or item.attack_cooldown > 0.0:
		return
	item.attack_cooldown = item.definition.secondary_recovery
	actor.confirm_hit(CombatHit.melee(actor, item.definition.secondary_damage, item.definition.melee_range, 70.0, item.definition.impact_impulse))
	actor.equipped.animate_action(&"swing", 0.25)

func reload() -> void:
	if item == null or reload_remaining > 0.0 or item.rounds == item.definition.magazine_size:
		return
	reload_remaining = item.definition.reload_seconds
	actor.equipped.animate_action(&"reload", reload_remaining)

func tick(delta: float) -> void:
	if reload_remaining <= 0.0:
		return
	reload_remaining = maxf(0.0, reload_remaining - delta)
	if reload_remaining == 0.0 and item != null:
		item.rounds = item.definition.magazine_size

func cancel_action() -> void:
	reload_remaining = 0.0

func unequip() -> void:
	cancel_action()
	super.unequip()

func status_text() -> String:
	if item == null:
		return ""
	if reload_remaining > 0.0:
		return "RELOADING  %.1fs" % reload_remaining
	return "%02d / %02d   ·   R Reload   ·   RMB Whip" % [item.rounds, item.definition.magazine_size]
