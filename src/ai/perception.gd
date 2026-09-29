class_name Perception
extends RefCounted
## Sight + hearing -> awareness (0..1).
##
## Sight: range & field of view from AI data, blocked by terrain (ray),
## reduced at night, in fog and while the creature sleeps. Awareness builds
## gradually so the player can back off or sneak. Hearing: loud events
## (EventBus.noise_emitted) inside radius set an investigation point.

var c: Creature
var awareness := 0.0
var sees_player := false
var last_known := Vector3.ZERO
var heard_at := Vector3.ZERO
var heard_time := -100.0
var time_since_seen := 999.0

var _sight_timer := 0.0
var _range := 18.0
var _fov := 110.0
var _hearing := 1.0


func _init(creature: Creature) -> void:
	c = creature
	_range = c.type.ai_value("sight_range", 18.0)
	_fov = c.type.ai_value("fov", 110.0)
	_hearing = c.type.ai_value("hearing", 1.0)
	EventBus.noise_emitted.connect(_on_noise)


func update(delta: float) -> void:
	time_since_seen += delta
	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = 0.2 if c.tier == Creature.Tier.FULL else 0.6
		sees_player = _check_sight()
	if sees_player:
		var p := Game.player
		time_since_seen = 0.0
		last_known = p.global_position
		var d := c.global_position.distance_to(p.global_position)
		var gain := (1.0 - d / effective_range()) * 2.2
		if (p as Player).sprinting:
			gain *= 1.6
		if d < 4.0:
			gain = 5.0
		awareness = minf(awareness + maxf(gain, 0.25) * delta, 1.0)
	else:
		awareness = maxf(awareness - delta * 0.12, 0.0)


func effective_range() -> float:
	var r := _range
	r *= lerpf(0.55, 1.0, Clock.daylight())
	r *= 1.0 - Weather.fog * 0.5
	if c.brain and c.brain.is_sleeping():
		r *= 0.25
	return maxf(r, 3.0)


func _check_sight() -> bool:
	var p := Game.player as Player
	if p == null or p.is_dead():
		return false
	var to := p.global_position - c.global_position
	var d := to.length()
	if d > effective_range():
		return false
	if d > 3.0:
		var flat := Vector3(to.x, 0, to.z).normalized()
		if c.facing_dir().angle_to(flat) > deg_to_rad(_fov * 0.5):
			return false
	var eye := c.global_position + Vector3.UP * c.type.collider_height * 0.85
	return CombatUtils.line_of_sight(c.get_world_3d(), eye, p.chest_position(), [c.get_rid()])


func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if c.dead or c.tier == Creature.Tier.DORMANT or source == c:
		return
	var r := radius * _hearing
	if c.brain and c.brain.is_sleeping():
		r *= 0.5
	if c.global_position.distance_to(pos) <= r:
		heard_at = pos
		heard_time = Time.get_ticks_msec() / 1000.0
		awareness = maxf(awareness, 0.45)


func recently_heard(window: float = 4.0) -> bool:
	return Time.get_ticks_msec() / 1000.0 - heard_time < window


func alert(pos: Vector3) -> void:
	awareness = 1.0
	last_known = pos
	time_since_seen = 0.0
