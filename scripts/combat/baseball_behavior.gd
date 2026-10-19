extends WeaponBehavior

var charging: bool = false
var charge_elapsed: float = 0.0

func primary(pressed: bool) -> void:
	if item == null:
		return
	if pressed:
		if not charging and item.attack_cooldown <= 0.0:
			charging = true
			charge_elapsed = 0.0
	elif charging:
		var power := lerpf(0.25, 1.0, charge_fraction())
		cancel_action()
		actor.throw_selected(power)

func secondary(pressed: bool) -> void:
	if not pressed or item == null or item.attack_cooldown > 0.0:
		return
	cancel_action()
	actor.throw_selected(0.2, true)

func tick(delta: float) -> void:
	if charging and item != null:
		charge_elapsed = minf(charge_elapsed + delta, item.definition.charge_seconds)
		actor.equipped.set_charge(charge_fraction())

func charge_fraction() -> float:
	return clampf(charge_elapsed / maxf(item.definition.charge_seconds, 0.01), 0.0, 1.0) if item != null else 0.0

func cancel_action() -> void:
	charging = false
	charge_elapsed = 0.0
	if is_instance_valid(actor):
		actor.equipped.set_charge(0.0)

func unequip() -> void:
	cancel_action()
	super.unequip()

func status_text() -> String:
	return "CHARGE  %03d%% · release LMB" % int(charge_fraction() * 100) if charging else "HOLD LMB Charge   ·   RMB Underhand toss"
