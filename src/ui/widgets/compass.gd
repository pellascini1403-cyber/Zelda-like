class_name Compass
extends Control
## Heading bar: the definitive compass PNG (a black-20 % pill) under the
## celeste centre marker, which marks the exact screen centre and the
## player's heading. Cardinal letters, DISCOVERED places, the player's pin,
## the tracked quest objective (the celeste quest diamond) and active world
## events slide along it. HUD palette only. No route line: navigation stays
## about reading the land.

const FOV_DEG := 150.0
const RANGE := 700.0
## The pill sits this far under the top of the control (the centre marker
## lives above it).
const BAR_Y := 22.0

var pin := Vector3.INF
var _font: Font
var _title: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	size = Vector2(HudArt.COMPASS_SIZE.x, BAR_Y + HudArt.COMPASS_SIZE.y)
	_font = UITheme.font()
	_title = UITheme.title_font()


func _process(_delta: float) -> void:
	queue_redraw()


## Horizontal centre of the control (= the screen centre once laid out).
func center_x() -> float:
	return size.x * 0.5


func _draw() -> void:
	var bar := Rect2(Vector2(0, BAR_Y), HudArt.COMPASS_SIZE)
	draw_texture_rect(HudArt.COMPASS_BAR, bar, false)
	var cs := HudArt.fit(HudArt.COMPASS_CENTER, HudArt.CENTER_W)
	draw_texture_rect(HudArt.COMPASS_CENTER, Rect2(Vector2(center_x() - cs.x * 0.5, 0), cs), false)
	var rig := Game.camera_rig as CameraRig
	if rig == null or Game.player == null:
		return
	var heading := fposmod(-rig.yaw, 360.0)   # 0 = north (-Z)
	var marks := {0.0: "N", 90.0: "E", 180.0: "S", 270.0: "W"}
	for deg in marks:
		var x := _x_for(float(deg), heading)
		if x < 0.0:
			continue
		var txt: String = marks[deg]
		var w := _title.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x
		HudArt.text(self, _title, Vector2(x - w * 0.5, BAR_Y + 31), txt, 20)
	var ppos := Game.player.global_position
	for poi in DB.world.get("pois", []):
		if not WorldState.is_poi_discovered(poi["id"]):
			continue
		var p: Array = poi["pos"]
		_marker(Vector3(p[0], 0, p[1]), ppos, heading, "dot")
	var gw := Game.world as GameWorld
	if gw and gw.events:
		var bp: Variant = gw.events.beacon_position()
		if bp != null:
			_marker(bp, ppos, heading, "event")
	# Tracked objective: the quest diamond. "Search the area" goals hide it
	# once the player is inside the area.
	var qm := Quests.tracked_marker()
	if not qm.is_empty():
		var qp: Vector3 = qm["pos"]
		if String(qm["hint"]) == "area":
			var dd := Vector2(qp.x - ppos.x, qp.z - ppos.z).length()
			if dd > float(qm["radius"]) * 0.8:
				_marker(qp, ppos, heading, "area")
		else:
			_marker(qp, ppos, heading, "quest")
	if pin != Vector3.INF:
		_marker(pin, ppos, heading, "pin")


func _marker(world: Vector3, ppos: Vector3, heading: float, kind: String) -> void:
	var to := world - ppos
	# A marker not placeable yet (Vector3.INF) has no bearing: drawing it at
	# NaN is what made the canvas fail to triangulate.
	if not (is_finite(to.x) and is_finite(to.z)):
		return
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
		x = 30.0 if diff < 0.0 else size.x - 30.0
	# Markers ride the lower half of the pill, under the cardinal letters.
	var y := BAR_Y + 43.0
	match kind:
		"dot":
			draw_circle(Vector2(x, y), 3.5, HudArt.WHITE)
		"pin":
			draw_circle(Vector2(x, y + 3), 4.5, HudArt.WHITE)
			draw_line(Vector2(x, y + 3), Vector2(x, y - 7), HudArt.WHITE, 2.0)
		"event":
			draw_arc(Vector2(x, y), 5.0, 0, TAU, 14, HudArt.WHITE, 2.0, true)
		"quest", "area":
			var ds := HudArt.fit(HudArt.QUEST_DIAMOND, HudArt.DIAMOND_W)
			draw_texture_rect(HudArt.QUEST_DIAMOND, Rect2(Vector2(x, y) - ds * 0.5, ds), false)
			if kind == "quest" and d > 30.0:
				var t := "%dm" % int(d)
				var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
				var tx := x + ds.x * 0.5 + 4.0
				if tx + w > size.x - 24.0:
					tx = x - ds.x * 0.5 - 4.0 - w
				HudArt.text(self, _font, Vector2(tx, y + 5), t, 14)


func _x_for(bearing: float, heading: float) -> float:
	var diff := wrapf(bearing - heading, -180.0, 180.0)
	if absf(diff) > FOV_DEG * 0.5:
		return -1.0
	return size.x * 0.5 + diff / (FOV_DEG * 0.5) * (size.x * 0.5 - 30.0)
