class_name TitleCard
extends Control
## Big centred card for discoveries, quests, bosses and learned abilities:
## engraved title between ornamental rules, subtitle below. Queued so cards
## never overlap; fades in, holds, fades out.

var _queue: Array = []
var _t := -1.0
var _title := ""
var _sub := ""
var _tf: Font
var _bf: Font

const IN := 0.5
const HOLD := 2.6
const OUT := 0.8


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tf = UITheme.title_font()
	_bf = UITheme.font()
	EventBus.title_card.connect(show_card)


func show_card(title: String, subtitle: String) -> void:
	if title == "":
		return
	_queue.append([title, subtitle])


func _process(delta: float) -> void:
	if _t < 0.0:
		if _queue.is_empty():
			return
		var n: Array = _queue.pop_front()
		_title = n[0]
		_sub = n[1]
		_t = 0.0
	_t += delta
	if _t > IN + HOLD + OUT:
		_t = -1.0
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var a := clampf(_t / IN, 0.0, 1.0) * (1.0 - clampf((_t - IN - HOLD) / OUT, 0.0, 1.0))
	var vs := get_viewport_rect().size
	var cy := vs.y * 0.3
	var tsz := UITheme.fs(52)
	var ssz := UITheme.fs(24)
	var tw := _tf.get_string_size(_title, HORIZONTAL_ALIGNMENT_CENTER, -1, tsz).x
	# Soft ink band behind the text
	var band := Rect2(Vector2(0, cy - tsz * 1.2), Vector2(vs.x, tsz * 2.4))
	for i in 8:
		var k := float(i) / 8.0
		draw_rect(Rect2(band.position + Vector2(0, band.size.y * k), Vector2(vs.x, band.size.y / 8.0)), Color(0, 0, 0, 0.28 * a * (1.0 - absf(k - 0.45) * 2.0)))
	var spread := clampf(_t / (IN + 0.4), 0.0, 1.0)
	var half := (tw * 0.5 + 60.0) * (0.6 + 0.4 * spread)
	var col := Color(UIArt.GOLD, a)
	UIArt.divider(self, Vector2(vs.x * 0.5 - half, cy - tsz * 0.95), Vector2(vs.x * 0.5 + half, cy - tsz * 0.95), col)
	UIArt.divider(self, Vector2(vs.x * 0.5 - half, cy + tsz * 0.45), Vector2(vs.x * 0.5 + half, cy + tsz * 0.45), col)
	draw_string_outline(_tf, Vector2(vs.x * 0.5 - tw * 0.5, cy), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 8, Color(0, 0, 0, 0.5 * a))
	draw_string(_tf, Vector2(vs.x * 0.5 - tw * 0.5, cy), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(UIArt.PAPER, a))
	if _sub != "":
		var sw := _bf.get_string_size(_sub, HORIZONTAL_ALIGNMENT_CENTER, -1, ssz).x
		draw_string_outline(_bf, Vector2(vs.x * 0.5 - sw * 0.5, cy + tsz * 1.0), _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz, 6, Color(0, 0, 0, 0.5 * a))
		draw_string(_bf, Vector2(vs.x * 0.5 - sw * 0.5, cy + tsz * 1.0), _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz, Color(UIArt.GOLD, a))
