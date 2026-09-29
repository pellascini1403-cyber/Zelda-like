class_name AIManager
extends Node
## Distance-based AI simulation budget.
##   FULL    (< ai_full_distance)     : ticked every physics frame
##   REDUCED (< ai_reduced_distance)  : ticked every 4th frame (delta accumulated)
##   DORMANT (beyond)                 : not ticked, animation paused
## Creatures never run their own _physics_process: the manager drives them,
## which also gives one place to profile AI cost.

const REDUCED_STRIDE := 4

var _frame := 0
var _accum: Dictionary = {}
var last_tick_usec := 0
var counts := [0, 0, 0]


func _physics_process(delta: float) -> void:
	if Game.player == null or not Game.is_playing():
		return
	var start := Time.get_ticks_usec()
	_frame += 1
	var q := Quality.current()
	var full_d2: float = pow(q["ai_full_distance"], 2)
	var red_d2: float = pow(q["ai_reduced_distance"], 2)
	var ppos := Game.player.global_position
	counts = [0, 0, 0]
	for n in get_tree().get_nodes_in_group(&"creatures"):
		var c := n as Creature
		if c == null or c.type == null or not c.is_inside_tree():
			continue
		var d2 := c.global_position.distance_squared_to(ppos)
		var tier := Creature.Tier.FULL if d2 < full_d2 else (Creature.Tier.REDUCED if d2 < red_d2 else Creature.Tier.DORMANT)
		if c.brain and c.brain.aggro and tier == Creature.Tier.DORMANT:
			tier = Creature.Tier.REDUCED
		if tier != c.tier:
			c.tier = tier
			c.visual.set_process(tier != Creature.Tier.DORMANT)
		counts[tier] += 1
		var id := c.get_instance_id()
		match tier:
			Creature.Tier.FULL:
				c.ai_tick(delta)
			Creature.Tier.REDUCED:
				_accum[id] = _accum.get(id, 0.0) + delta
				if (_frame + id) % REDUCED_STRIDE == 0:
					c.ai_tick(minf(_accum[id], 0.2))
					_accum[id] = 0.0
			_:
				_accum.erase(id)
	last_tick_usec = Time.get_ticks_usec() - start
