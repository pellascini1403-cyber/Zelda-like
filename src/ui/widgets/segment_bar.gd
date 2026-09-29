class_name SegmentBar
extends Control
## Segmented health bar (each segment = 20 HP). Lost health trails behind so
## damage reads clearly.

var value := 1.0
var max_segments := 5
var color := UITheme.HEALTH
var _trail := 1.0


func _process(delta: float) -> void:
	_trail = move_toward(_trail, value, delta * (0.5 if _trail > value else 5.0))
	custom_minimum_size.x = maxf(60.0 * max_segments, 200.0)
	queue_redraw()


func _draw() -> void:
	var gap := 5.0
	var w := (size.x - gap * (max_segments - 1)) / max_segments
	for i in max_segments:
		var x := i * (w + gap)
		var r := Rect2(x, 0, w, size.y)
		draw_style_box(UITheme.box(Color(0, 0, 0, 0.5), 6), r)
		var seg_lo := float(i) / max_segments
		var seg_hi := float(i + 1) / max_segments
		var trail_fill := clampf((_trail - seg_lo) / (seg_hi - seg_lo), 0.0, 1.0)
		var fill := clampf((value - seg_lo) / (seg_hi - seg_lo), 0.0, 1.0)
		if trail_fill > 0.0:
			draw_style_box(UITheme.box(Color(1, 0.9, 0.8, 0.6), 6), Rect2(x, 0, w * trail_fill, size.y))
		if fill > 0.0:
			draw_style_box(UITheme.box(color, 6), Rect2(x, 0, w * fill, size.y))
