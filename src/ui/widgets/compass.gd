class_name Compass
extends Control
## Heading strip. Shows cardinal points, DISCOVERED places within range and
## the player's own map pin. No route line, no GPS: navigation stays about
## reading the land.

const WIDTH := 520.0
const FOV_DEG := 150.0
const RANGE := 700.0

var pin := Vector3.INF
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH, 52)
	_font = UITheme.font()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rig := Game.camera_rig as CameraRig
	if rig == null or Game.player == null:
		return
	draw_style_box(UITheme.box(Color(0.05, 0.06, 0.08, 0.45), 18), Rect2(Vector2.ZERO, size))
	var heading := fposmod(-rig.yaw, 360.0)   # 0 = north (-Z)
	var marks := {0.0: "N", 90.0: "E", 180.0: "S", 270.0: "W", 45.0: "·", 135.0: "·", 225.0: "·", 315.0: "·"}
	for deg in marks:
		var x := _x_for(float(deg), heading)
		if x < 0.0:
			continue
		var txt: String = marks[deg]
		var fsz := 22 if txt != "·" else 26
		var col := UITheme.ACCENT if txt == "N" else UITheme.TEXT
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz).x
		draw_string(_font, Vector2(x - w * 0.5, 34), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz, col)
	var ppos := Game.player.global_position
	for poi in DB.world.get("pois", []):
		if not WorldState.is_poi_discovered(poi["id"]):
			continue
		var p: Array = poi["pos"]
		_marker(Vector3(p[0], 0, p[1]), ppos, heading, UITheme.ACCENT_2)
	if pin != Vector3.INF:
		_marker(pin, ppos, heading, UITheme.DANGER)
	draw_line(Vector2(size.x * 0.5, 4), Vector2(size.x * 0.5, 12), UITheme.ACCENT, 2.0)


func _marker(world: Vector3, ppos: Vector3, heading: float, col: Color) -> void:
	var to := world - ppos
	var d := Vector2(to.x, to.z).length()
	if d > RANGE or d < 8.0:
		return
	var bearing := fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)
	var x := _x_for(bearing, heading)
	if x < 0.0:
		return
	draw_circle(Vector2(x, 44), 5.0, col)


func _x_for(bearing: float, heading: float) -> float:
	var diff := wrapf(bearing - heading, -180.0, 180.0)
	if absf(diff) > FOV_DEG * 0.5:
		return -1.0
	return size.x * 0.5 + diff / (FOV_DEG * 0.5) * (size.x * 0.5 - 20.0)
