class_name StaminaRing
extends Control
## Stamina: a jade ring beside the character inside a thin gold hoop; hidden
## when full. Turns cinnabar and pulses while exhausted.

var _ratio := 1.0
var _exhausted := false
var _alpha := 0.0
var _pulse := 0.0
var _screen_pos := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func follow(p: Player, ratio: float, exhausted: bool, delta: float) -> void:
	_ratio = ratio
	_exhausted = exhausted
	var visible_target := 1.0 if ratio < 0.999 or exhausted else 0.0
	_alpha = move_toward(_alpha, visible_target, delta * (4.0 if visible_target > 0.0 else 1.2))
	_pulse = maxf(_pulse - delta * 2.0, 0.0)
	var cam := get_viewport().get_camera_3d()
	if cam and not cam.is_position_behind(p.global_position):
		_screen_pos = cam.unproject_position(p.global_position + Vector3.UP * 1.2) + Vector2(70, -40)
	queue_redraw()


func pulse() -> void:
	_pulse = 1.0


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var r := 26.0 + _pulse * 6.0
	var col := UITheme.DANGER if _exhausted else UITheme.STAMINA
	col.a = _alpha
	draw_circle(_screen_pos, r + 5, Color(0, 0, 0, 0.32 * _alpha))
	draw_arc(_screen_pos, r + 6.5, 0, TAU, 48, Color(UIArt.GOLD, 0.55 * _alpha), 1.4, true)
	draw_arc(_screen_pos, r, 0, TAU, 48, Color(0, 0, 0, 0.35 * _alpha), 8.0, true)
	draw_arc(_screen_pos, r, -PI * 0.5, -PI * 0.5 + TAU * _ratio, 48, col, 8.0, true)
	UIArt.diamond(self, _screen_pos + Vector2(0, -r - 6.5), 3.0, Color(UIArt.GOLD, _alpha))
