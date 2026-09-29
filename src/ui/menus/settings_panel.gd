class_name SettingsPanel
extends ScrollContainer
## All player options: audio, controls, camera, graphics/performance,
## language, accessibility, privacy, game (save / quit).

var _list: VBoxContainer
var _confirm_delete := false


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	_header("SET_AUDIO")
	_slider("SET_MUSIC", "music_volume", 0.0, 1.0)
	_slider("SET_SFX", "sfx_volume", 0.0, 1.0)
	_slider("SET_AMBIENCE", "ambience_volume", 0.0, 1.0)
	_header("SET_CONTROLS")
	_slider("SET_CAMERA_SENS", "camera_sensitivity", 0.3, 2.5)
	_toggle("SET_INVERT_Y", "invert_y")
	_toggle("SET_AUTO_CAMERA", "auto_camera")
	_slider("SET_CONTROLS_SIZE", "controls_scale", 0.75, 1.4)
	_slider("SET_CONTROLS_OPACITY", "controls_opacity", 0.3, 1.0)
	_toggle("SET_LEFT_HANDED", "left_handed")
	_toggle("SET_VIBRATION", "vibration")
	_header("SET_GRAPHICS")
	_options("SET_QUALITY", "quality", [["SET_Q_AUTO", -1], ["SET_Q_LOW", 0], ["SET_Q_MEDIUM", 1], ["SET_Q_HIGH", 2], ["SET_Q_ULTRA", 3]])
	_options("SET_FPS", "fps_target", [["30", 30], ["60", 60]])
	_toggle("SET_DYNAMIC_RES", "dynamic_resolution")
	_toggle("SET_BATTERY", "battery_saver")
	_toggle("SET_SHOW_FPS", "show_fps")
	_header("SET_ACCESSIBILITY")
	_slider("SET_TEXT_SIZE", "text_scale", 0.85, 1.5)
	_toggle("SET_SUBTITLES", "subtitles")
	var langs := [["SET_LANG_AUTO", ""]]
	for l in Settings.LANGUAGES:
		langs.append(["LANG_" + l.to_upper(), l])
	_options("SET_LANGUAGE", "language", langs)
	_header("SET_PRIVACY")
	_toggle("SET_ANALYTICS", "analytics_consent")
	_header("SET_GAME")
	var row := HBoxContainer.new()
	_list.add_child(row)
	var save_b := UITheme.button(tr("ACT_SAVE"), 64)
	save_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_b.pressed.connect(func() -> void:
		if SaveSystem.save_game():
			EventBus.toast.emit(tr("TOAST_SAVED")))
	row.add_child(save_b)
	var quit_b := UITheme.button(tr("ACT_QUIT_TO_MENU"), 64)
	quit_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_b.pressed.connect(func() -> void: Game.return_to_menu())
	row.add_child(quit_b)
	var ver := UITheme.label("VELA %s · %s" % [ProjectSettings.get_setting("application/config/version"), OS.get_name()], 16, UITheme.TEXT_DIM)
	_list.add_child(ver)


func _header(key: String) -> void:
	var l := UITheme.label(tr(key), 26, UITheme.ACCENT)
	_list.add_child(l)


func _row(key: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size.y = 64
	var l := UITheme.label(tr(key), 22)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	_list.add_child(h)
	return h


func _slider(key: String, setting: String, lo: float, hi: float) -> void:
	var h := _row(key)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Settings.get_value(setting))
	s.custom_minimum_size = Vector2(320, 48)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float) -> void: Settings.set_value(setting, v, false))
	s.drag_ended.connect(func(_c: bool) -> void:
		Settings.save_settings()
		if setting == "text_scale":
			refresh())
	h.add_child(s)


func _toggle(key: String, setting: String) -> void:
	var h := _row(key)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_value(setting))
	c.focus_mode = Control.FOCUS_NONE
	c.custom_minimum_size = Vector2(90, 48)
	c.toggled.connect(func(v: bool) -> void: Settings.set_value(setting, v))
	h.add_child(c)


func _options(key: String, setting: String, opts: Array) -> void:
	var h := _row(key)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(320, 56)
	o.focus_mode = Control.FOCUS_NONE
	var cur: Variant = Settings.get_value(setting)
	for i in opts.size():
		o.add_item(tr(opts[i][0]))
		if opts[i][1] == cur:
			o.select(i)
	o.item_selected.connect(func(i: int) -> void:
		var v: Variant = opts[i][1]
		Settings.set_value(setting, v)
		if setting == "quality":
			Quality.set_level(Quality.detected_level if int(v) < 0 else int(v), false)
			Settings.set_value("quality", v)
		if setting == "language":
			refresh())
	h.add_child(o)
