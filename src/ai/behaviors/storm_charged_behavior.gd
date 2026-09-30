class_name StormChargedBehavior
extends AIBehavior
## In a storm it drinks the lightning: attacks turn electric, it sparks, and
## every few seconds it discharges around itself (a disc warns). Outside a
## storm it is just its base self. Soaked targets take double shock.

var _t := 3.0
var _pending := -1.0


func charged() -> bool:
	return Weather.storm > 0.4


func attack_element(_a: AttackData) -> StringName:
	return &"electric" if charged() else &""


func pre_tick(delta: float) -> StringName:
	if not charged() or c.tier != Creature.Tier.FULL:
		return &""
	_t -= delta
	if _pending >= 0.0:
		_pending -= delta
		if _pending < 0.0:
			_discharge()
	elif _t <= 0.0 and b.current.id() in [&"chase", &"attack"] and c.distance_to_player() < 7.0:
		_t = float(param("discharge_every", 6.0))
		_pending = 0.9
		Telegraph.disc(c, c.global_position, 3.6, 0.9, ElementFX.color(&"electric"))
	return &""


func _discharge() -> void:
	for body in CombatUtils.sphere_query(c.get_world_3d(), c.global_position, 3.6, CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK):
		var info := DamageInfo.make(10.0, c, Vector3.UP * 3.0, &"electric")
		info.kind = &"slam"
		info.blockable = false
		CombatUtils.deal(body, info)
	ElementFX.burst(c.get_parent(), c.global_position, &"electric", 3.6)
	Audio.play_at(&"zap", c.global_position, 0.0)
