class_name Surf
extends Node3D
## Breaking surf at a sea-cave mouth or a reef gap. At high tide (and in any
## storm) waves throw swimmers and boats back out; at low tide the way is
## calm. `dir` is the direction the waves push (out to sea).

var radius := 5.0
var dir := Vector3.BACK
var _t := 0.0
var _warned := false


static func create(r: float, push_dir: Vector3) -> Surf:
	var s := Surf.new()
	s.radius = r
	s.dir = push_dir.normalized()
	return s


static func active() -> bool:
	return Tide.is_high() or Tide.level() > 0.6 or Weather.storm > 0.4


func _physics_process(delta: float) -> void:
	if not active() or Game.player == null:
		return
	_t -= delta
	var p := Game.player as Player
	var body: Node3D = p.vehicle if p.vehicle else p
	var d := Vector2(body.global_position.x - global_position.x, body.global_position.z - global_position.z).length()
	if _t <= 0.0 and d < radius * 2.5:
		_t = 1.2
		Effects.splash(self, global_position + Vector3(randf_range(-radius, radius), 0.2, randf_range(-radius, radius)) * Vector3(1, 1, 0.5))
	if d < radius and body.global_position.y < WorldGen.SEA_LEVEL + 1.5:
		var push := dir * 9.0 + Vector3.UP * 1.5
		if body is Vehicle:
			(body as Vehicle).velocity += push * delta * 4.0
		else:
			p.velocity += push * delta * 4.0
		if not _warned:
			_warned = true
			EventBus.toast.emit(tr("HINT_SURF"))
