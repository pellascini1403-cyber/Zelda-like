class_name EncounterBanner
extends Control
## Live challenge banner under the compass: "Protect Pip · Wave 2/3" with
## a HUD bar (protected person's health, time left, course progress).
## Driven by EventBus.encounter_hud; an empty title hides it.

var _title := ""
var _detail := ""
var _ratio := 0.0
var _shown := 0.0
var _target := 0.0
var _font: Font
var _title_font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(460, 64)
	size = custom_minimum_size
	_font = UITheme.font()
	_title_font = UITheme.title_font()
	EventBus.encounter_hud.connect(func(title: String, detail: String, ratio: float) -> void:
		_title = title if title != "" else _title
		_detail = detail
		_ratio = ratio
		_target = 1.0 if title != "" else 0.0)


func _process(delta: float) -> void:
	_shown = move_toward(_shown, _target, delta * 4.0)
	visible = _shown > 0.01
	if visible:
		queue_redraw()


func _draw() -> void:
	var a := _shown
	var w := size.x
	draw_rect(Rect2(Vector2(0, 4), Vector2(w, 56)), Color(HudArt.SHADE, HudArt.SHADE.a * a))
	var fs := UITheme.fs(22)
	HudArt.text(self, _title_font, Vector2(14, 32), _title, fs, a, HudArt.WHITE, w * 0.6)
	var dfs := UITheme.fs(19)
	var dw := _font.get_string_size(_detail, HORIZONTAL_ALIGNMENT_RIGHT, -1, dfs).x
	HudArt.text(self, _font, Vector2(w - 14 - dw, 32), _detail, dfs, a)
	HudArt.bar(self, Rect2(Vector2(14, 42), Vector2(w - 28, 10)), _ratio, a)
