class_name IgniteBehavior
extends AIBehavior
## Leaves burning ground where it runs (fire spreads over dry grass through
## the normal FireSource rules). Rain or water snuffs its flame: doused, its
## attacks lose their fire and it takes much more damage.
## Tuning: ignite_every (s).

var _t := 0.0


func doused() -> bool:
	return Weather.rain > 0.4 or c.health.has_status(&"wet")


func pre_tick(delta: float) -> StringName:
	_t -= delta
	if _t <= 0.0 and c.tier == Creature.Tier.FULL and b.current.id() in [&"chase", &"patrol", &"attack"]:
		_t = float(param("ignite_every", 3.0))
		if not doused() and c.global_position.y > WorldGen.SEA_LEVEL + 0.2:
			FireSource.ignite_at(c.get_parent(), c.global_position - c.facing_dir() * 0.8, 5.0)
	return &""


func attack_element(a: AttackData) -> StringName:
	if a.element == &"fire" and doused():
		return &"none"
	return &""


func filter_damage(info: DamageInfo) -> void:
	if doused():
		info.amount *= 1.6
