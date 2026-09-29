class_name WindSight
extends Node3D
## Wind Sight: a pulse that reveals nearby chests, resource nodes and
## undiscovered places with floating glyphs visible through walls, for a few
## seconds. Markers are pooled Label3D (no textures, no extra materials).

const MAX_MARKERS := 24

var _markers: Array[Label3D] = []
var _time := 0.0


func _ready() -> void:
	for i in MAX_MARKERS:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0022
		l.font_size = 42
		l.outline_size = 10
		l.visible = false
		add_child(l)
		_markers.append(l)
	set_process(false)


func reveal(origin: Vector3, radius: float, duration: float) -> void:
	for m in _markers:
		m.visible = false
	var found: Array = []
	for n in get_tree().get_nodes_in_group(&"chests"):
		var c := n as Node3D
		if c and not (c.get("opened") == true) and c.global_position.distance_to(origin) < radius:
			found.append([c.global_position + Vector3.UP * 1.2, "◆", Color(1.0, 0.82, 0.4)])
	for n in get_tree().get_nodes_in_group(&"resource_nodes"):
		var r := n as Node3D
		if r and r.visible and r.global_position.distance_to(origin) < radius * 0.6:
			found.append([r.global_position + Vector3.UP * 1.0, "✦", Color(0.55, 1.0, 0.7)])
	for poi in DB.world.get("pois", []):
		var p := Vector3(poi["pos"][0], 0, poi["pos"][1])
		if not WorldState.is_poi_discovered(poi["id"]) and Vector2(p.x - origin.x, p.z - origin.z).length() < radius * 3.0:
			p.y = float(poi.get("pad_height", origin.y)) + 12.0
			found.append([p, "❖", Color(0.7, 0.9, 1.0)])
	found.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector3).distance_squared_to(origin) < (b[0] as Vector3).distance_squared_to(origin))
	for i in mini(found.size(), MAX_MARKERS):
		var m := _markers[i]
		m.text = found[i][1]
		m.modulate = found[i][2]
		m.outline_modulate = Color(0, 0, 0, 0.6)
		m.global_position = found[i][0]
		m.visible = true
	_time = duration
	set_process(true)
	ElementFX.burst(self, origin, &"wind", radius * 0.25)


func _process(delta: float) -> void:
	_time -= delta
	var a := clampf(_time / 1.5, 0.0, 1.0)
	for m in _markers:
		if m.visible:
			m.modulate.a = a * (0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006))
	if _time <= 0.0:
		for m in _markers:
			m.visible = false
		set_process(false)
