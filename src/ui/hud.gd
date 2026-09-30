class_name HUD
extends CanvasLayer
## In-game overlay. Minimal by design: vitals, compass, time/weather, a
## context prompt, transient feedback. Everything else lives in menus.
## Look and layout follow the definitive HUD reference (HudArt): hearts,
## compass and buttons are the delivered PNGs, text is white with a black
## outline, and no colour outside the HUD palette is used.

var island: IslandMap
var touch: TouchControls
var compass: Compass
var menu: PauseMenu
var dialogue: DialogueBox
var cooking: CookingPanel

var _root: Control
var _hearts: HeartRow
var _stamina: StaminaRing
var _status: Label
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
var board: BoardPanel
var altar: AltarPanel
var banner: EncounterBanner
var rewards: RewardPopup
var _jade: Label
var _jade_t := 0.0
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
	vs.code = "shader_type canvas_item;\nuniform float amount = 0.0;\nuniform vec4 tint : source_color = vec4(0.0,0.0,0.0,1.0);\nvoid fragment(){ float d = distance(UV, vec2(0.5)); COLOR = vec4(tint.rgb, smoothstep(0.35, 0.8, d) * amount); }"
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
	_top_left.add_theme_constant_override("separation", 0)
	_root.add_child(_top_left)
	_hearts = HeartRow.new()
	_top_left.add_child(_hearts)
	_status = HudArt.label("", 20)
	_top_left.add_child(_status)
	_buffs = HBoxContainer.new()
	_top_left.add_child(_buffs)
	# Jade count: shows for a moment whenever it changes.
	_jade = HudArt.label("", 20)
	_jade.modulate.a = 0.0
	_top_left.add_child(_jade)

	# Top-center compass
	compass = Compass.new()
	_root.add_child(compass)

	# Top-right: the four menu buttons
	_top_right = HBoxContainer.new()
	_top_right.add_theme_constant_override("separation", int(HudArt.BUTTON_GAP))
	_root.add_child(_top_right)
	for pair in [["map", PauseMenu.TAB_MAP], ["journal", PauseMenu.TAB_JOURNAL], ["bag", PauseMenu.TAB_INVENTORY], ["pause", PauseMenu.TAB_SETTINGS]]:
		var gb := GlyphButton.make(pair[0])
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

	banner = EncounterBanner.new()
	_root.add_child(banner)
	rewards = RewardPopup.new()
	_root.add_child(rewards)
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
	board = BoardPanel.new()
	add_child(board)
	altar = AltarPanel.new()
	add_child(altar)
	EventBus.panel_requested.connect(func(panel: StringName, arg: String) -> void:
		if panel == &"board":
			board.open_board(arg)
		elif panel == &"garage":
			menu.open_garage(arg == "bench")
		elif panel == &"altar":
			altar.open_panel(tr("ALTAR_TITLE")))
	EventBus.jade_changed.connect(func(total: int) -> void:
		_jade.text = "%d  %s" % [total, tr("JADE")]
		_jade_t = 4.0)

	EventBus.toast.connect(show_toast)
	EventBus.item_acquired.connect(_on_item)
	EventBus.player_damaged.connect(func(amount: float, _s: Node) -> void:
		_vignette_t = clampf(amount / 30.0, 0.35, 1.0))
	EventBus.perfect_dodge.connect(func() -> void: _flash_screen(Color(HudArt.CELESTE, 0.35)))
	EventBus.parry_success.connect(func(_p: Vector3) -> void: _flash_screen(Color(HudArt.WHITE, 0.3)))
	EventBus.weapon_durability_warning.connect(func(id: StringName) -> void:
		show_toast(tr("TOAST_WEAPON_WORN") % tr(DB.item(id).name_key)))
	EventBus.weapon_broken.connect(func(id: StringName) -> void:
		show_toast(tr("TOAST_WEAPON_BROKE") % tr(DB.item(id).name_key)))
	EventBus.game_saved.connect(func() -> void: _feed_line(tr("TOAST_SAVED")))
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
	# Reference layout (1280x720, 24/16 margins): hearts at (38, 29) with the
	# status line under them, the compass pill at y 29 with its centre
	# marker above it on the exact screen centre, the buttons at y 29 ending
	# 46 px from the right edge, the tracker right-aligned under them.
	_top_left.position = Vector2(m["left"], m["top"] + 13.0)
	_top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_top_right.offset_right = -m["right"] - 22.0
	_top_right.offset_top = m["top"] + 13.0
	_top_right.offset_left = _top_right.offset_right - _top_right.get_combined_minimum_size().x
	compass.position = Vector2(vs.x * 0.5 - compass.center_x(), m["top"] + 13.0 - Compass.BAR_Y)
	_toasts.position = Vector2(vs.x * 0.5 - 300, m["top"] + 70)
	_toasts.size = Vector2(600, 200)
	_feed.position = Vector2(vs.x - m["right"] - 360, m["top"] + 230)
	_feed.size = Vector2(360, 300)
	banner.position = Vector2(vs.x * 0.5 - banner.size.x * 0.5, m["top"] + 66)
	rewards.position = Vector2(m["left"], vs.y * 0.34)
	tracker.position = Vector2(vs.x - m["right"] - 420, m["top"] + 76)
	tracker.size = Vector2(420, 140)
	(tracker.get_child(0) as Control).size = Vector2(420, 140)
	ability.position = Vector2(vs.x - m["right"] - 90, vs.y - m["bottom"] - 110)
	_spurs.position = Vector2(vs.x * 0.5 - 80, vs.y - m["bottom"] - 40)


func _process(delta: float) -> void:
	var p := Game.player as Player
	if p == null:
		return
	_hearts.value = PlayerData.health / PlayerData.max_health
	_hearts.max_segments = int(PlayerData.max_health / 20.0)
	_stamina.follow(p, p.vitals.ratio(), p.vitals.exhausted, delta)
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
	# On the coast the tide matters (sandbars, cave mouths): show it.
	if p.region == &"coast":
		status.append(tr(Tide.label_key()))
	_status.text = "  ".join(status)
	_update_buffs()
	if _jade_t > 0.0:
		_jade_t -= delta
		_jade.modulate.a = clampf(_jade_t, 0.0, 1.0)
	_spurs.visible = p.mount != null
	if _spurs.visible:
		_spurs.queue_redraw()
	# Low health pulse + damage flash
	_vignette_t = maxf(_vignette_t - delta * 1.5, 0.0)
	var low := 1.0 - smoothstep(0.15, 0.3, PlayerData.health / PlayerData.max_health)
	var cold := 0.35 if exp < 0 else 0.0
	var mat := _vignette.material as ShaderMaterial
	mat.set_shader_parameter("amount", maxf(_vignette_t, low * (0.5 + 0.2 * sin(Time.get_ticks_msec() * 0.006))) + cold)
	mat.set_shader_parameter("tint", HudArt.CELESTE if cold > 0.0 and _vignette_t <= 0.0 else HudArt.BLACK)
	if Input.is_action_just_pressed("inventory"):
		open_menu(PauseMenu.TAB_INVENTORY)
	elif Input.is_action_just_pressed("map"):
		open_menu(PauseMenu.TAB_MAP)
	elif Input.is_action_just_pressed("menu") and not menu.visible and not cooking.visible:
		open_menu(PauseMenu.TAB_SETTINGS)


func _update_buffs() -> void:
	var want := PlayerData.buffs.size()
	while _buffs.get_child_count() < want:
		_buffs.add_child(HudArt.label("", 16))
	while _buffs.get_child_count() > want:
		var c := _buffs.get_child(_buffs.get_child_count() - 1)
		_buffs.remove_child(c)
		c.queue_free()
	var i := 0
	for id in PlayerData.buffs:
		var b: Dictionary = PlayerData.buffs[id]
		(_buffs.get_child(i) as Label).text = "%s %d:%02d" % [tr("BUFF_" + String(id).to_upper()), int(b["remaining"]) / 60, int(b["remaining"]) % 60]
		i += 1


func open_menu(tab: int) -> void:
	if Game.state != Game.State.PLAYING:
		return
	menu.open(tab)


func show_toast(text: String) -> void:
	var l := HudArt.label(text, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 600
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
	_feed_line("+%d  %s" % [count, tr(it.name_key)])


func _feed_line(text: String) -> void:
	var l := HudArt.label(text, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size.x = 360
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
		UIArt.diamond(_spurs, c, 9.0, HudArt.SHADE)
		if fill > 0.0:
			UIArt.diamond(_spurs, c, 7.0 * fill, HudArt.CELESTE)
