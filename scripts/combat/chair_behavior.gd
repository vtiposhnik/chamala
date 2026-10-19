extends WeaponBehavior
## The chair has one action: commit the held object to a heavy physical throw.

func primary(pressed: bool) -> void:
	if pressed and item != null:
		actor.throw_selected()

func status_text() -> String:
	return "LMB / F Heavy throw · two-handed · recover with E"
