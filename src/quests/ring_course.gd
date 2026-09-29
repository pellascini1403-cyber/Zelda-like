class_name RingCourse
extends Node3D
## Timed challenge through a chain of wind rings: glide courses off cliffs,
## foot races along ridges, swims between sea stacks, mounted gallops.
## Passing ring 0 starts the clock; the next ring glows gold, the one after
## it faintly. Finishing emits EventBus.course_finished(id, seconds) —
## quest objectives of type "course" may demand a par time.
##
## Data (kind "course"): {id, mode: glide|run|swim|ride, rings: [[x,y,z] |
## {pos: [x,z], h: metres above ground}], ring_radius, par, limit, title_key}
## (positions are resolved by QuestSpawner before the course is built).
## Failing (time out, landing mid-glide, wandering off) just resets it.

const PASS_STATES := {
	"glide": [&"glide", &"air", &"gust"],
	"swim": [&"swim"],
	"ride": [&"ride"],
}

var course_id: StringName = &""
var mode := "run"
var points: Array[Vector3] = []
var ring_radius := 4.0
var par := 0.0
var limit := 120.0
var title_key := "COURSE_TITLE"
var _rings: Array[MeshInstance3D] = []
var _next := 0
var _running := false
var _time := 0.0
var _grounded_t := 0.0
var _beam: MeshInstance3D
var _mat_next: StandardMaterial3D
var _mat_after: StandardMaterial3D
var _mat_idle: StandardMaterial3D
var _hud_t := 0.0
static var _torus: TorusMesh


static func create(d: Dictionary, resolved: Array[Vector3]) -> RingCourse:
	var c := RingCourse.new()
	c.course_id = StringName(d.get("id", ""))
	c.mode = String(d.get("mode", "run"))
	c.points = resolved
	c.ring_radius = float(d.get("ring_radius", 4.5 if c.mode == "glide" else 3.0))
	c.par = float(d.get("par", 0.0))
	c.limit = float(d.get("limit", maxf(c.par * 2.0, 60.0)))
	c.title_key = String(d.get("title_key", "COURSE_TITLE"))
	return c


func _ready() -> void:
	add_to_group(&"ring_courses")
	if _torus == null:
		_torus = TorusMesh.new()
		_torus.inner_radius = 0.86
		_torus.outer_radius = 1.0
		_torus.rings = 24
		_torus.ring_segments = 6
	_mat_next = _glow(Color(1.0, 0.82, 0.38, 0.95))
	_mat_after = _glow(Color(0.55, 0.9, 0.72, 0.35))
	_mat_idle = _glow(Color(1.0, 0.82, 0.38, 0.8))
	for i in points.size():
		var mi := MeshInstance3D.new()
		mi.mesh = _torus
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * ring_radius
		mi.visibility_range_end = 420.0
		add_child(mi)
		mi.global_position = points[i]
		# Face the ring along the course (TorusMesh lies in XZ: tilt it up).
		var dir := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)])
		dir.y = 0.0
		var yaw := atan2(dir.x, dir.z) if dir.length() > 0.1 else 0.0
		mi.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5) * Basis().scaled(Vector3.ONE * ring_radius)
		_rings.append(mi)
	# A thin light beam marks the start from afar (visual cue, no map icon).
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.5
	cyl.height = 40.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 8
	_beam = MeshInstance3D.new()
	_beam.mesh = cyl
	_beam.material_override = _glow(Color(1.0, 0.85, 0.5, 0.35))
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visibility_range_end = 600.0
	add_child(_beam)
	if not points.is_empty():
		_beam.global_position = points[0] + Vector3(0, 20.0 - ring_radius, 0)
	_reset(false)


static func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func is_running() -> bool:
	return _running


func _reset(failed: bool) -> void:
	_running = false
	_next = 0
	_time = 0.0
	_grounded_t = 0.0
	for i in _rings.size():
		_rings[i].visible = i == 0
		_rings[i].material_override = _mat_idle
	if _beam:
		_beam.visible = true
	if failed:
		EventBus.toast.emit(tr("COURSE_FAILED"))
		EventBus.encounter_hud.emit("", "", 0.0)


func _show_next() -> void:
	for i in _rings.size():
		_rings[i].visible = i == _next or i == _next + 1
		_rings[i].material_override = _mat_next if i == _next else _mat_after


func _state_ok(p: Player) -> bool:
	var need: Array = PASS_STATES.get(mode, [])
	return need.is_empty() or p.state_name() in need


func _physics_process(delta: float) -> void:
	var p := Game.player as Player
	if p == null or points.is_empty():
		return
	if _hud_t > 0.0:
		_hud_t -= delta
		if _hud_t <= 0.0:
			EventBus.encounter_hud.emit("", "", 0.0)
	var spin := Time.get_ticks_msec() * 0.001
	if _next < _rings.size():
		_rings[_next].rotate_object_local(Vector3.UP, delta * 0.6)
		_rings[_next].scale = Vector3.ONE * ring_radius * (1.0 + 0.04 * sin(spin * 5.0))
	var target := points[_next]
	var close := p.global_position.distance_to(target) < ring_radius + 0.6
	if not _running:
		if close and _state_ok(p) and not p.is_dead():
			_running = true
			_beam.visible = false
			_pass()
		return
	_time += delta
	if mode == "glide" and not _state_ok(p):
		_grounded_t += delta
	else:
		_grounded_t = 0.0
	if _time > limit or _grounded_t > 1.2 or p.is_dead() or p.global_position.distance_to(target) > 160.0:
		_reset(true)
		return
	EventBus.encounter_hud.emit(tr(title_key), "%.1f s" % _time + ("  ·  %s %.0f s" % [tr("COURSE_PAR"), par] if par > 0.0 else ""), clampf(float(_next) / points.size(), 0.0, 1.0))
	if close and _state_ok(p):
		_pass()


func _pass() -> void:
	var at := points[_next]
	ElementFX.ring(self, at, &"wind", ring_radius * 0.5, 0.35)
	Audio.play_at(&"ring", at, -3.0, 0.02 + _next * 0.01)
	_next += 1
	if _next >= points.size():
		_finish()
	else:
		_show_next()


func _finish() -> void:
	var t := _time
	var key := "course_best:" + String(course_id)
	var best := float(WorldState.flags.get(key, 0.0))
	if best <= 0.0 or t < best:
		WorldState.flags[key] = t
	var line := tr("COURSE_DONE") % t
	if par > 0.0:
		line += "  " + (tr("COURSE_PAR_BEAT") if t <= par else tr("COURSE_PAR_MISSED"))
	EventBus.toast.emit(line)
	EventBus.encounter_hud.emit(tr(title_key), "%.1f s" % t, 1.0)
	_hud_t = 3.0
	Audio.play_ui(&"quest_stage", -2.0)
	EventBus.course_finished.emit(course_id, t)
	_reset(false)
