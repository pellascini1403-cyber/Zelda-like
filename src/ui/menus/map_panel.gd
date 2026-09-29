class_name MapPanel
extends Control
## Parchment map revealed by exploration. Only DISCOVERED places get a
## marker (no icon soup). Tap to place / remove a personal pin that also
## appears on the compass. Pinch/drag free: the island fits the screen.

var _tex: ImageTexture
var _fog: ImageTexture
var _font: Font
var _map_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = UITheme.font()


func refresh() -> void:
	var hud: HUD = Game.world.hud if Game.world else null
	if hud and hud.island and hud.island.map_image and _tex == null:
		_tex = ImageTexture.create_from_image(hud.island.map_image)
	_build_fog()
	queue_redraw()


func _build_fog() -> void:
	var n := WorldState.MAP_CELLS
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for z in n:
		for x in n:
			# Unexplored = blank parchment with a faint hint of the land below.
			img.set_pixel(x, z, Color(0.78, 0.71, 0.57, 0.0 if WorldState.is_explored(x, z) else 0.86))
	if _fog == null:
		_fog = ImageTexture.create_from_image(img)
	else:
		_fog.update(img)


func _draw() -> void:
	var s := minf(size.x, size.y) - 10.0
	_map_rect = Rect2(Vector2((size.x - s) * 0.5, (size.y - s) * 0.5), Vector2(s, s))
	draw_rect(_map_rect.grow(8), Color(0.33, 0.26, 0.18))
	draw_rect(_map_rect, Color(0.8, 0.73, 0.58))
	if _tex:
		draw_texture_rect(_tex, _map_rect, false)
	if _fog:
		draw_texture_rect(_fog, _map_rect, false)
	for poi in DB.world.get("pois", []):
		if not WorldState.is_poi_discovered(poi["id"]):
			continue
		var p: Array = poi["pos"]
		var sp := _to_map(Vector3(p[0], 0, p[1]))
		var col := UITheme.ACCENT if poi["type"] == "village" else UITheme.ACCENT_2
		draw_circle(sp, 9, Color(0, 0, 0, 0.6))
		draw_circle(sp, 6, col)
		var name := tr(poi["name_key"])
		draw_string(_font, sp + Vector2(12, 6), name, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.fs(18), Color(0.12, 0.1, 0.08))
	var hud: HUD = Game.world.hud if Game.world else null
	if hud and hud.compass.pin != Vector3.INF:
		var pp := _to_map(hud.compass.pin)
		draw_circle(pp, 10, UITheme.DANGER)
		draw_circle(pp, 4, Color.WHITE)
	if Game.player:
		var pl := _to_map(Game.player.global_position)
		var fwd := (Game.player as Player).facing_dir()
		var d := Vector2(fwd.x, fwd.z)
		var side := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([pl + d * 16, pl - d * 9 + side * 9, pl - d * 9 - side * 9]), Color.WHITE)
		draw_polyline(PackedVector2Array([pl + d * 16, pl - d * 9 + side * 9, pl - d * 9 - side * 9, pl + d * 16]), Color.BLACK, 2.0)
	draw_string(_font, _map_rect.position + Vector2(12, 30), tr("MAP_HINT"), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.fs(18), Color(0.12, 0.1, 0.08))


func _to_map(w: Vector3) -> Vector2:
	var u := (w.x + WorldGen.WORLD_HALF) / (WorldGen.WORLD_HALF * 2.0)
	var v := (w.z + WorldGen.WORLD_HALF) / (WorldGen.WORLD_HALF * 2.0)
	return _map_rect.position + Vector2(u, v) * _map_rect.size


func _gui_input(event: InputEvent) -> void:
	var pressed_pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed_pos = event.position
	if pressed_pos == Vector2.INF or not _map_rect.has_point(pressed_pos):
		return
	var hud: HUD = Game.world.hud
	var rel := (pressed_pos - _map_rect.position) / _map_rect.size
	var w := Vector3(rel.x * WorldGen.WORLD_HALF * 2.0 - WorldGen.WORLD_HALF, 0, rel.y * WorldGen.WORLD_HALF * 2.0 - WorldGen.WORLD_HALF)
	if hud.compass.pin != Vector3.INF and _to_map(hud.compass.pin).distance_to(pressed_pos) < 24.0:
		hud.compass.pin = Vector3.INF
	else:
		hud.compass.pin = w
	Audio.play_ui(&"ui_click", -6.0)
	queue_redraw()
