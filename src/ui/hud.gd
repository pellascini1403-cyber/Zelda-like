class_name HUD
extends CanvasLayer
## In-game overlay. Minimal by design: vitals, compass, time/weather, a
## context prompt, transient feedback. Everything else lives in menus.

var island: IslandMap
var touch: TouchControls
var compass: Compass
var menu: PauseMenu
var dialogue: DialogueBox
var cooking: CookingPanel

var _root: Control
var _health_bar: SegmentBar
var _stamina: StaminaRing
var _status: Label
var _clock: Label
var _toasts: VBoxContainer
var _feed: VBoxContainer
var _vignette: ColorRect
var _vignette_t := 0.0
var _flash: ColorRect
var _top_right: HBoxContainer
var _top_left: VBoxContainer
var _buffs: HBoxContainer
var tracker: QuestTracker
var title_card: TitleCard
var boss_plate: BossPlate
var ability: AbilityIndicator
var shop: ShopPanel
var _spurs: Control


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := Shader.new()
	vs.code = "shader_type canvas_item;\nuniform float amount = 0.0;\nuniform vec4 tint : source_color = vec4(0.8,0.1,0.1,1.0);\nvoid fragment(){ float d = distance(UV, vec2(0.5)); COLOR = vec4(tint.rgb, smoothstep(0.35, 0.8, d) * amount); }"
	var vm := ShaderMaterial.new()
	vm.shader = vs
	_vignette.material = vm
	_root.add_child(_vignette)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_root.add_child(_flash)

	touch = TouchControls.new()
	_root.add_child(touch)

	_stamina = StaminaRing.new()
	_root.add_child(_stamina)

	# Top-left: health + status
	_top_left = VBoxContainer.new()
	_top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top_left)
	_health_bar = SegmentBar.new()
	_health_bar.custom_minimum_size = Vector2(320, 26)
	_top_left.add_child(_health_bar)
	_buffs = HBoxContainer.new()
	_top_left.add_child(_buffs)
	_status = UITheme.label("", 20, UITheme.TEXT)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_status.add_theme_constant_override("outline_size", 6)
	_top_left.add_child(_status)

	# Top-center compass
	compass = Compass.new()
	_root.add_child(compass)

	# Top-right: clock + buttons
	_top_right = HBoxContainer.new()
	_root.add_child(_top_right)
	_clock = UITheme.label("", 20, UITheme.TEXT)
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_clock.add_theme_constant_override("outline_size", 6)
	_top_right.add_child(_clock)
	for pair in [["map", PauseMenu.TAB_MAP], ["journal", PauseMenu.TAB_JOURNAL], ["bag", PauseMenu.TAB_INVENTORY], ["pause", PauseMenu.TAB_SETTINGS]]:
		var gb := GlyphButton.make(pair[0], 58.0)
		var tab: int = pair[1]
		gb.pressed.connect(func() -> void: open_menu(tab))
		_top_right.add_child(gb)
	touch.blockers.append(_top_right)
	tracker = QuestTracker.new()
	_root.add_child(tracker)
	ability = AbilityIndicator.new()
	_root.add_child(ability)
	_spurs = Control.new()
	_spurs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spurs.custom_minimum_size = Vector2(160, 24)
	_spurs.draw.connect(_draw_spurs)
	_root.add_child(_spurs)

	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_toasts)
	_feed = VBoxContainer.new()
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_feed)

	dialogue = DialogueBox.new()
	_root.add_child(dialogue)
	touch.blockers.append(dialogue)
	boss_plate = BossPlate.new()
	_root.add_child(boss_plate)
	title_card = TitleCard.new()
	_root.add_child(title_card)

	menu = PauseMenu.new()
	menu.hud = self
	add_child(menu)
	cooking = CookingPanel.new()
	add_child(cooking)
	shop = ShopPanel.new()
	add_child(shop)

	EventBus.toast.connect(show_toast)
	EventBus.item_acquired.connect(_on_item)
	EventBus.player_damaged.connect(func(amount: float, _s: Node) -> void:
		_vignette_t = clampf(amount / 30.0, 0.35, 1.0))
	EventBus.perfect_dodge.connect(func() -> void: _flash_screen(Color(0.6, 0.9, 1.0, 0.35)))
	EventBus.parry_success.connect(func(_p: Vector3) -> void: _flash_screen(Color(1.0, 0.9, 0.6, 0.3)))
	EventBus.weapon_durability_warning.connect(func(id: StringName) -> void:
		show_toast(tr("TOAST_WEAPON_WORN") % tr(DB.item(id).name_key)))
	EventBus.weapon_broken.connect(func(id: StringName) -> void:
		show_toast(tr("TOAST_WEAPON_BROKE") % tr(DB.item(id).name_key)))
	EventBus.game_saved.connect(func() -> void: _feed_line(tr("TOAST_SAVED"), UITheme.TEXT_DIM))
	EventBus.station_opened.connect(func(station: StringName, node: Node3D) -> void:
		if station == &"campfire":
			cooking.open(node)
		elif station == &"shop":
			shop.open(node))
	EventBus.stamina_exhausted.connect(func() -> void: _stamina.pulse())
	# Full-screen menus own the screen: hide the HUD underneath.
	EventBus.menu_toggled.connect(func(open: bool) -> void: _root.visible = not open)
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()


func _layout() -> void:
	var m := UITheme.safe_margins(get_viewport())
	var vs := _root.get_viewport_rect().size
	_top_left.position = Vector2(m["left"], m["top"])
	_top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_top_right.offset_right = -m["right"]
	_top_right.offset_top = m["top"]
	_top_right.offset_left = _top_right.offset_right - _top_right.get_combined_minimum_size().x
	compass.position = Vector2(vs.x * 0.5 - compass.size.x * 0.5, m["top"])
	_toasts.position = Vector2(vs.x * 0.5 - 300, m["top"] + 70)
	_toasts.size = Vector2(600, 200)
	_feed.position = Vector2(vs.x - m["right"] - 360, m["top"] + 230)
	_feed.size = Vector2(360, 300)
	tracker.position = Vector2(vs.x - m["right"] - 420, m["top"] + 74)
	tracker.size = Vector2(420, 140)
	(tracker.get_child(0) as Control).size = Vector2(420, 140)
	ability.position = Vector2(vs.x - m["right"] - 90, vs.y - m["bottom"] - 110)
	_spurs.position = Vector2(vs.x * 0.5 - 80, vs.y - m["bottom"] - 40)


func _process(delta: float) -> void:
	var p := Game.player as Player
	if p == null:
		return
	_health_bar.value = PlayerData.health / PlayerData.max_health
	_health_bar.max_segments = int(PlayerData.max_health / 20.0)
	_stamina.follow(p, p.vitals.ratio(), p.vitals.exhausted, delta)
	_clock.text = "%s  %s" % [_time_string(), tr("WEATHER_" + String(Weather.target).to_upper())]
	var status := PackedStringArray()
	var exp := p.vitals.exposure
	if exp < 0:
		status.append(tr("STATUS_FREEZING"))
	elif exp > 0:
		status.append(tr("STATUS_HOT"))
	status.append("%d°C" % int(round(p.vitals.temperature)))
	for s in p.health.statuses:
		status.append(tr("STATUS_" + String(s).to_upper()))
	if PlayerData.carries_metal() and Weather.storm > 0.5 and not PlayerData.lightning_immune():
		status.append(tr("STATUS_METAL_STORM"))
	_status.text = "  ".join(status)
	_status.add_theme_color_override("font_color", UITheme.DANGER if exp != 0 else UITheme.TEXT)
	_update_buffs()
	_spurs.visible = p.mount != null
	if _spurs.visible:
		_spurs.queue_redraw()
	# Low health pulse + damage flash
	_vignette_t = maxf(_vignette_t - delta * 1.5, 0.0)
	var low := 1.0 - smoothstep(0.15, 0.3, PlayerData.health / PlayerData.max_health)
	var cold := 0.35 if exp < 0 else 0.0
	var mat := _vignette.material as ShaderMaterial
	mat.set_shader_parameter("amount", maxf(_vignette_t, low * (0.5 + 0.2 * sin(Time.get_ticks_msec() * 0.006))) + cold)
	mat.set_shader_parameter("tint", Color(0.5, 0.75, 1.0) if cold > 0.0 and _vignette_t <= 0.0 else Color(0.8, 0.1, 0.1))
	if Input.is_action_just_pressed("inventory"):
		open_menu(PauseMenu.TAB_INVENTORY)
	elif Input.is_action_just_pressed("map"):
		open_menu(PauseMenu.TAB_MAP)
	elif Input.is_action_just_pressed("menu") and not menu.visible and not cooking.visible:
		open_menu(PauseMenu.TAB_SETTINGS)


func _update_buffs() -> void:
	var want := PlayerData.buffs.size()
	while _buffs.get_child_count() < want:
		_buffs.add_child(UITheme.label("", 16, UITheme.ACCENT_2))
	while _buffs.get_child_count() > want:
		var c := _buffs.get_child(_buffs.get_child_count() - 1)
		_buffs.remove_child(c)
		c.queue_free()
	var i := 0
	for id in PlayerData.buffs:
		var b: Dictionary = PlayerData.buffs[id]
		(_buffs.get_child(i) as Label).text = "%s %d:%02d" % [tr("BUFF_" + String(id).to_upper()), int(b["remaining"]) / 60, int(b["remaining"]) % 60]
		i += 1


func _time_string() -> String:
	var h := int(Clock.hour)
	var m := int((Clock.hour - h) * 60.0) / 10 * 10
	return "%s  %02d:%02d" % [tr("HUD_DAY") % Clock.day, h, m]


func open_menu(tab: int) -> void:
	if Game.state != Game.State.PLAYING:
		return
	menu.open(tab)


func show_toast(text: String) -> void:
	var l := UITheme.label(text, 24, UITheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 600
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	_toasts.add_child(l)
	if _toasts.get_child_count() > 3:
		_toasts.get_child(0).queue_free()
	var t := l.create_tween()
	t.tween_interval(2.6)
	t.tween_property(l, "modulate:a", 0.0, 0.6)
	t.tween_callback(l.queue_free)


func _on_item(id: StringName, count: int) -> void:
	var it := DB.item(id)
	if it == null:
		return
	_feed_line("+%d  %s" % [count, tr(it.name_key)], ItemIcons.category_color(it.category))


func _feed_line(text: String, color: Color) -> void:
	var l := UITheme.label(text, 20, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size.x = 360
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	_feed.add_child(l)
	if _feed.get_child_count() > 6:
		_feed.get_child(0).queue_free()
	var t := l.create_tween()
	t.tween_interval(2.2)
	t.tween_property(l, "modulate:a", 0.0, 0.5)
	t.tween_callback(l.queue_free)


func _flash_screen(c: Color) -> void:
	_flash.color = c
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)


## Mount spur charges (riding only).
func _draw_spurs() -> void:
	var p := Game.player as Player
	if p == null or p.mount == null:
		return
	var mt := p.mount
	var n := int(mt.m("stamina", 4))
	for i in n:
		var c := Vector2(20 + i * 30, 12)
		var fill := clampf(mt.spurs - i, 0.0, 1.0)
		UIArt.diamond(_spurs, c, 9.0, Color(0, 0, 0, 0.5))
		UIArt.diamond(_spurs, c, 7.0 * maxf(fill, 0.25), Color(UIArt.JADE_LIGHT, 0.4 + 0.6 * fill))
