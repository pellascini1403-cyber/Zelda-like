class_name PhaseBehavior
extends AIBehavior
## Fades out of the world and back: while faded it cannot be hit and drifts
## to a new spot. It must show itself to attack, and fire or a burning
## weapon near it forces it back into sight.
## Tuning: phase_on, phase_off (s).

var _t := 0.0
var _out := false


func pre_tick(delta: float) -> StringName:
	_t += delta
	var id := b.current.id()
	if _out:
		var hot := _heat_near()
		if _t > float(param("phase_off", 2.5)) or hot:
			_set_out(false)
			if hot:
				c.health.add_status(&"burning", 1.5)
		elif Game.player and id == &"chase":
			var a := randf() * TAU
			c.go_to(Game.player.global_position + Vector3(cos(a), 0, sin(a)) * 6.0, c.type.run_speed)
	elif id in [&"chase", &"patrol", &"search"] and _t > float(param("phase_on", 4.0)):
		_set_out(true)
	return &""


func _set_out(on: bool) -> void:
	_out = on
	_t = 0.0
	c.set_hidden(on)
	c.visual.set_fade(0.85 if on else 0.0)
	b.attack_blocked = on
	Effects.sparks(c, c.global_position + Vector3.UP * c.type.collider_height * 0.5, ArtStyle.vfx_color(c.type), 0.3)


func _heat_near() -> bool:
	for h in c.get_tree().get_nodes_in_group(&"heat_source"):
		if (h as Node3D).global_position.distance_to(c.global_position) < 5.0:
			return true
	return false
