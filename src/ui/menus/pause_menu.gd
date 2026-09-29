class_name PauseMenu
extends CanvasLayer
## Full-screen menu (pauses the game): Inventory · Crafting · Map · Settings.
## Tabs are big touch targets; every panel is scroll-friendly.

enum { TAB_INVENTORY, TAB_CRAFTING, TAB_MAP, TAB_JOURNAL, TAB_SETTINGS }

var hud: HUD
var _root: Control
var _tabs: HBoxContainer
var _content: Control
var _panels: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _current := 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.05, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	# Ink wash: darker edges, a faint jade glow at the centre.
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec2 d = UV - vec2(0.5, 0.45); float r = length(d * vec2(1.3, 1.0)); COLOR = mix(vec4(0.12, 0.2, 0.17, 0.35), vec4(0.0, 0.0, 0.0, 0.55), smoothstep(0.1, 0.75, r)); }"
	var wm := ShaderMaterial.new()
	wm.shader = sh
	wash.material = wm
	_root.add_child(wash)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(margin)
	var m := UITheme.safe_margins(_root.get_viewport())
	margin.add_theme_constant_override("margin_left", int(m["left"]) + 8)
	margin.add_theme_constant_override("margin_right", int(m["right"]) + 8)
	margin.add_theme_constant_override("margin_top", int(m["top"]) + 8)
	margin.add_theme_constant_override("margin_bottom", int(m["bottom"]) + 8)
	var v := VBoxContainer.new()
	margin.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_tabs = HBoxContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_tabs)
	for key in ["TAB_INVENTORY", "TAB_CRAFTING", "TAB_MAP", "TAB_JOURNAL", "TAB_SETTINGS"]:
		var b := UITheme.button(tr(key), 64)
		b.custom_minimum_size.x = 150
		b.toggle_mode = true
		var idx := _tab_buttons.size()
		b.pressed.connect(func() -> void: show_tab(idx))
		_tabs.add_child(b)
		_tab_buttons.append(b)
	var close := UITheme.button(tr("BTN_RESUME"), 64)
	close.custom_minimum_size.x = 170
	close.pressed.connect(close_menu)
	top.add_child(close)
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_content)
	for p: Control in [InventoryPanel.new(), CraftingPanel.new(), MapPanel.new(), JournalPanel.new(), SettingsPanel.new()]:
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		p.visible = false
		_content.add_child(p)
		_panels.append(p)


func open(tab: int) -> void:
	visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.18)
	Game.set_paused(true)
	show_tab(tab)
	Audio.play_ui(&"menu_open", -6.0)


func close_menu() -> void:
	visible = false
	Game.set_paused(false)
	Audio.play_ui(&"menu_close", -8.0)


func show_tab(i: int) -> void:
	_current = i
	for k in _panels.size():
		_panels[k].visible = k == i
		if k == i:
			_panels[k].modulate.a = 0.0
			_panels[k].create_tween().tween_property(_panels[k], "modulate:a", 1.0, 0.15)
		_tab_buttons[k].button_pressed = k == i
	if _panels[i].has_method("refresh"):
		_panels[i].refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("menu") or event.is_action_pressed("inventory") and _current == TAB_INVENTORY or event.is_action_pressed("map") and _current == TAB_MAP:
		close_menu()
		get_viewport().set_input_as_handled()
