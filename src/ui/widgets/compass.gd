class_name Compass
extends Control
## Heading scroll: an ink strip between two rolled ends, engraved cardinal
## letters, tick marks, DISCOVERED places, the player's pin, the tracked
## quest objective (gold diamond) and active world events. No route line:
## navigation stays about reading the land.

const WIDTH := 560.0
const FOV_DEG := 150.0
const RANGE := 700.0

var pin := Vector3.INF
var _font: Font
var _title: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH, 50)
	_font = UITheme.font()
	_title = UITheme.title_font()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rig := Game.camera_rig as CameraRig
	if rig == null or Game.player == null:
		return
	var body := Rect2(Vector2(14, 8), Vector2(size.x - 28, 34))
	draw_rect(body, Color(UIArt.INK, 0.55))
	draw_line(body.position, Vector2(body.end.x, body.position.y), Color(UIArt.GOLD, 0.55), 1.2)
	draw_line(Vector2(body.position.x, body.end.y), body.end, Color(UIArt.GOLD, 0.55), 1.2)
	# Rolled ends
	for x in [body.position.x, body.end.x]:
		draw_rect(Rect2(Vector2(x - 5, 4), Vector2(10, 42)), Color(0.3, 0.2, 0.13, 0.9))
		draw_rect(Rect2(Vector2(x - 5, 4), Vector2(10, 42)), Color(UIArt.GOLD, 0.7), false, 1.2)
		draw_circle(Vector2(x, 3), 4, UIArt.GOLD)
		draw_circle(Vector2(x, 47), 4, UIArt.GOLD)
	var heading := fposmod(-rig.yaw, 360.0)   # 0 = north (-Z)
	# Ticks every 15°
	for i in 24:
		var deg := i * 15.0
		var x := _x_for(deg, heading)
		if x < 0.0:
			continue
		var major := i % 6 == 0
		draw_line(Vector2(x, body.end.y - (9 if major else 5)), Vector2(x, body.end.y - 1), Color(UIArt.PAPER, 0.35 if not major else 0.6), 1.0)
	var marks := {0.0: "N", 90.0: "E", 180.0: "S", 270.0: "W"}
	for deg in marks:
		var x := _x_for(float(deg), heading)
		if x < 0.0:
			continue
		var txt: String = marks[deg]
		var col := UIArt.CINNABAR.lightened(0.2) if txt == "N" else UIArt.PAPER
		var w := _title.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x
		draw_string(_title, Vector2(x - w * 0.5, 33), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, col)
	var ppos := Game.player.global_position
	for poi in DB.world.get("pois", []):
		if not WorldState.is_poi_discovered(poi["id"]):
			continue
		var p: Array = poi["pos"]
		_marker(Vector3(p[0], 0, p[1]), ppos, heading, "dot", UITheme.ACCENT_2)
	var gw := Game.world as GameWorld
	if gw and gw.events:
		var bp: Variant = gw.events.beacon_position()
		if bp != null:
			_marker(bp, ppos, heading, "event", UIArt.JADE_LIGHT)
	# Tracked objective: an exact diamond, or for "search the area" goals a
	# broad arc that fades once the player is inside the area.
	var qm := Quests.tracked_marker()
	if not qm.is_empty():
		var qp: Vector3 = qm["pos"]
		if String(qm["hint"]) == "area":
			var dd := Vector2(qp.x - ppos.x, qp.z - ppos.z).length()
			if dd > float(qm["radius"]) * 0.8:
				_marker(qp, ppos, heading, "area", UIArt.GOLD)
		else:
			_marker(qp, ppos, heading, "quest", UIArt.GOLD)
	if pin != Vector3.INF:
		_marker(pin, ppos, heading, "pin", UITheme.DANGER)
	# Centre needle
	draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.5 - 6, 0), Vector2(size.x * 0.5 + 6, 0), Vector2(size.x * 0.5, 9)]), UIArt.GOLD)


func _marker(world: Vector3, ppos: Vector3, heading: float, kind: String, col: Color) -> void:
	var to := world - ppos
	var d := Vector2(to.x, to.z).length()
	if (d > RANGE and kind == "dot") or d < 8.0:
		return
	var bearing := fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)
	var x := _x_for(bearing, heading)
	if x < 0.0:
		# Off-scroll quest objective: clamp to the edge so it is never lost.
		if kind != "quest" and kind != "area":
			return
		var diff := wrapf(bearing - heading, -180.0, 180.0)
		x = 24.0 if diff < 0.0 else size.x - 24.0
	match kind:
		"dot":
			draw_circle(Vector2(x, 42), 4.0, col)
		"pin":
			draw_circle(Vector2(x, 42), 5.0, col)
			draw_line(Vector2(x, 42), Vector2(x, 32), col, 2.0)
		"quest":
			UIArt.diamond(self, Vector2(x, 42), 7.0, Color(0, 0, 0, 0.6))
			UIArt.diamond(self, Vector2(x, 42), 5.5, col)
			if d > 30.0:
				var t := "%dm" % int(d)
				var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
				draw_string(_font, Vector2(x - w * 0.5, 62), t, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(UIArt.GOLD, 0.9))
		"event":
			draw_arc(Vector2(x, 42), 5.0, 0, TAU, 14, col, 2.0, true)
		"area":
			draw_arc(Vector2(x, 42), 9.0, PI * 1.1, PI * 1.9, 10, Color(col, 0.9), 2.5, true)
			draw_arc(Vector2(x, 42), 5.0, 0, TAU, 12, Color(col, 0.5), 1.5, true)


func _x_for(bearing: float, heading: float) -> float:
	var diff := wrapf(bearing - heading, -180.0, 180.0)
	if absf(diff) > FOV_DEG * 0.5:
		return -1.0
	return size.x * 0.5 + diff / (FOV_DEG * 0.5) * (size.x * 0.5 - 30.0)
