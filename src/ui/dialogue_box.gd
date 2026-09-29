class_name DialogueBox
extends PanelContainer
## Subtitled dialogue / lore text. Tap (or interact/jump) to advance.
## Text reveals progressively; respects the subtitles & text size settings.

var _lines: PackedStringArray = []
var _index := 0
var _speaker: Label
var _text: Label
var _reveal := 0.0
var _trade: Button
var _trade_npc: Node3D = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	add_child(v)
	_speaker = UITheme.title("", 22, UITheme.ACCENT)
	v.add_child(_speaker)
	_text = UITheme.label("", 24)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(760, 90)
	v.add_child(_text)
	var row := HBoxContainer.new()
	v.add_child(row)
	_trade = UITheme.button(tr("BTN_TRADE"), 52)
	_trade.custom_minimum_size.x = 160
	_trade.visible = false
	_trade.pressed.connect(func() -> void:
		visible = false
		EventBus.station_opened.emit(&"shop", _trade_npc))
	row.add_child(_trade)
	var hint := UITheme.label(tr("DIALOGUE_TAP"), 16, UITheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	EventBus.dialogue_requested.connect(show_lines)
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	var vs := get_viewport_rect().size
	var m := UITheme.safe_margins(get_viewport())
	size = Vector2(minf(820.0, vs.x - 80.0), 0)
	position = Vector2(vs.x * 0.5 - size.x * 0.5, vs.y - m["bottom"] - 300.0)


func show_lines(speaker_key: String, lines: PackedStringArray) -> void:
	# Text is the only voice channel today; the subtitles setting will gate
	# on-screen text for voiced lines once VO exists.
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_trade.visible = false
	_trade_npc = null
	_speaker.text = tr(speaker_key)
	visible = true
	_layout()
	_show_current()


func _show_current() -> void:
	_text.text = tr(_lines[_index])
	_text.visible_ratio = 0.0
	_reveal = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_reveal += delta * 45.0 / maxf(_text.text.length(), 1.0)
	_text.visible_ratio = minf(_reveal, 1.0)
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
		advance()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		advance()
		accept_event()


func advance() -> void:
	if _text.visible_ratio < 1.0:
		_reveal = 1.0
		return
	_index += 1
	if _index >= _lines.size():
		visible = false
	else:
		_show_current()


## Offer a Trade button for this dialogue (merchants).
func offer_trade(npc: Node3D) -> void:
	_trade_npc = npc
	_trade.visible = true


func _draw() -> void:
	UIArt.corners(self, Rect2(Vector2(6, 6), size - Vector2(12, 12)), 16.0, Color(UIArt.GOLD, 0.7))
