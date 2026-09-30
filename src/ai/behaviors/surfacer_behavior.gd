class_name SurfacerBehavior
extends AIBehavior
## Big gentle swimmers (drift whales): cruise at depth, rise every so often
## to breathe — back out of the water, a spout of spray you can see from the
## shore — then sink again. Tuning: breathe_every, breathe_time.

var _t := 0.0
var _up := false


func pre_tick(delta: float) -> StringName:
	_t += delta
	if not _up and _t > float(param("breathe_every", 14.0)):
		_up = true
		_t = 0.0
		c.sink = -0.2
	elif _up and _t > float(param("breathe_time", 5.0)):
		_up = false
		_t = 0.0
		c.sink = float(param("swim_depth", 2.5))
	if _up and c.tier == Creature.Tier.FULL and fmod(_t, 1.6) < delta:
		var top := Vector3(c.global_position.x, WorldGen.SEA_LEVEL + 0.5, c.global_position.z)
		Effects.splash(c, top)
		Effects.splash(c, top + Vector3.UP * 1.5)
	return &""


func breathing() -> bool:
	return _up
