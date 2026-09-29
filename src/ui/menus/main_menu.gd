extends Control
## Title screen: Continue / New game / Settings / Quit. Painted backdrop of
## layered ridgelines (no external art needed; replace with a user image at
## res://assets/ui/title_background.png).

const BACKGROUND := "res://assets/ui/title_background.png"

var _settings_layer: Control
var _confirm: PanelContainer
var _t := 0.0


func _ready() -> void:
	Game.state = Game.State.MENU
	theme = UITheme.get_theme()
	InputRouter.release_mouse()
	if ResourceLoader.exists(BACKGROUND):
		var bg := TextureRect.new()
		bg.texture = load(BACKGROUND)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(bg)
	var m := UITheme.safe_margins(get_viewport())
	var v := VBoxContainer.new()
	v.position = Vector2(m["left"] + 60, 0)
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.offset_left = m["left"] + 60
	v.offset_top = -220
	v.custom_minimum_size = Vector2(420, 0)
	add_child(v)
	var title := UITheme.label("VELA", 110, UITheme.ACCENT)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	title.add_theme_constant_override("outline_size", 10)
	v.add_child(title)
	v.add_child(UITheme.label(tr("MENU_SUBTITLE"), 24, UITheme.TEXT))
	v.add_child(Control.new())
	if SaveSystem.has_save():
		var cont := UITheme.button(tr("MENU_CONTINUE"), 72)
		cont.pressed.connect(func() -> void: Game.start_game(true))
		v.add_child(cont)
	var new_b := UITheme.button(tr("MENU_NEW_GAME"), 72)
	new_b.pressed.connect(_on_new_game)
	v.add_child(new_b)
	var set_b := UITheme.button(tr("TAB_SETTINGS"), 72)
	set_b.pressed.connect(_open_settings)
	v.add_child(set_b)
	if not OS.has_feature("mobile"):
		var quit := UITheme.button(tr("MENU_QUIT"), 72)
		quit.pressed.connect(func() -> void: get_tree().quit())
		v.add_child(quit)
	var ver := UITheme.label("v%s" % ProjectSettings.get_setting("application/config/version"), 16, UITheme.TEXT_DIM)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = get_viewport_rect().size - Vector2(m["right"] + 80, m["bottom"] + 30)
	add_child(ver)
	Audio.play_music(&"music_title")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if ResourceLoader.exists(BACKGROUND):
		return
	var s := get_viewport_rect().size
	# Dusk sky gradient
	var steps := 160
	for i in steps:
		var t := float(i) / steps
		var c := Color(0.16, 0.22, 0.38).lerp(Color(0.95, 0.62, 0.45), pow(t, 1.6))
		draw_rect(Rect2(0, s.y * t, s.x, s.y / steps + 1), c)
	draw_circle(Vector2(s.x * 0.72, s.y * 0.62), s.y * 0.09, Color(1.0, 0.86, 0.62, 0.9))
	# Ridgelines, far to near
	var layers := [[0.55, Color(0.45, 0.42, 0.55), 0.06, 1.0], [0.66, Color(0.3, 0.3, 0.42), 0.09, 1.7], [0.78, Color(0.18, 0.2, 0.28), 0.12, 2.6], [0.9, Color(0.09, 0.11, 0.15), 0.1, 4.0]]
	for l in layers:
		var pts := PackedVector2Array()
		pts.append(Vector2(0, s.y))
		var n := 64
		for i in n + 1:
			var x := s.x * i / n
			var y: float = s.y * l[0] - (sin(x * 0.004 * l[3] + l[3]) * 0.5 + sin(x * 0.011 * l[3] + 1.3) * 0.3 + sin(x * 0.023 + _t * 0.05 * l[3]) * 0.1) * s.y * l[2]
			# The tall peak: something on the horizon worth reaching.
			if l[0] == 0.55:
				y -= exp(-pow((x - s.x * 0.66) / (s.x * 0.07), 2.0)) * s.y * 0.22
			pts.append(Vector2(x, y))
		pts.append(Vector2(s.x, s.y))
		draw_colored_polygon(pts, l[1])


func _on_new_game() -> void:
	if not SaveSystem.has_save():
		Game.start_game(false)
		return
	if _confirm:
		_confirm.queue_free()
	_confirm = PanelContainer.new()
	_confirm.set_anchors_preset(Control.PRESET_CENTER)
	_confirm.position = get_viewport_rect().size * 0.5 - Vector2(260, 100)
	add_child(_confirm)
	var v := VBoxContainer.new()
	_confirm.add_child(v)
	var l := UITheme.label(tr("MENU_OVERWRITE"), 24)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 480
	v.add_child(l)
	var h := HBoxContainer.new()
	v.add_child(h)
	var yes := UITheme.button(tr("MENU_YES"), 64)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func() -> void:
		SaveSystem.delete_save()
		Game.start_game(false))
	h.add_child(yes)
	var no := UITheme.button(tr("MENU_NO"), 64)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(func() -> void: _confirm.queue_free())
	h.add_child(no)


func _open_settings() -> void:
	if _settings_layer:
		_settings_layer.queue_free()
	_settings_layer = PanelContainer.new()
	_settings_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := UITheme.safe_margins(get_viewport())
	_settings_layer.offset_left = m["left"] + 20
	_settings_layer.offset_right = -m["right"] - 20
	_settings_layer.offset_top = m["top"] + 20
	_settings_layer.offset_bottom = -m["bottom"] - 20
	add_child(_settings_layer)
	var v := VBoxContainer.new()
	_settings_layer.add_child(v)
	var close := UITheme.button(tr("BTN_CLOSE_MENU"), 60)
	close.pressed.connect(func() -> void:
		_settings_layer.queue_free()
		get_tree().reload_current_scene())
	v.add_child(close)
	var sp := SettingsPanel.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	sp.refresh()
