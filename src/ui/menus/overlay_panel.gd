class_name OverlayPanel
extends CanvasLayer
## Shared frame for world-object panels (bounty board, Warden altar):
## dimmed backdrop, title, purse line, Leave button, a content column.
## Pauses the game while open.

var _root: Control
var _title: Label
var _purse: Label
var body: VBoxContainer


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.04, 0.84)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	_root.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UITheme.title("", 34)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_purse = UITheme.label("", 24, UITheme.ACCENT_2)
	_purse.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_purse)
	var close := UITheme.button(tr("BTN_LEAVE"), 58)
	close.custom_minimum_size.x = 160
	close.pressed.connect(close_panel)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)


func open_panel(title: String) -> void:
	_title.text = title
	visible = true
	Game.set_paused(true)
	refresh()
	Audio.play_ui(&"menu_open", -6.0)


func close_panel() -> void:
	visible = false
	Game.set_paused(false)


func refresh() -> void:
	pass


func clear_body() -> void:
	for c in body.get_children():
		c.queue_free()


## A framed card with a title, a wrapped text and an action button.
func card(title: String, text: String, action: String, enabled: bool, on_press: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UITheme.title(title, 24, UITheme.ACCENT))
	var l := UITheme.label(text, 19, UITheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	if action != "":
		var b := UITheme.button(action, 58)
		b.custom_minimum_size.x = 200
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not enabled
		b.pressed.connect(on_press)
		h.add_child(b)
	return p


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("menu"):
		close_panel()
		get_viewport().set_input_as_handled()
