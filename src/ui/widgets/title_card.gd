class_name TitleCard
extends Control
## Big centred card for discoveries, quests, bosses and learned abilities:
## title on a black-20 % band, subtitle below in celeste. Queued so cards
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
	draw_rect(Rect2(Vector2(0, cy - tsz * 1.1), Vector2(vs.x, tsz * 2.3)), Color(HudArt.SHADE, HudArt.SHADE.a * a))
	HudArt.text(self, _tf, Vector2(vs.x * 0.5 - tw * 0.5, cy), _title, tsz, a)
	if _sub != "":
		var sw := _bf.get_string_size(_sub, HORIZONTAL_ALIGNMENT_CENTER, -1, ssz).x
		HudArt.text(self, _bf, Vector2(vs.x * 0.5 - sw * 0.5, cy + tsz * 0.95), _sub, ssz, a, HudArt.CELESTE)
