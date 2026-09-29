class_name SegmentBar
extends Control
## Health as brush strokes (each stroke = 20 HP) separated by small gold
## diamonds. Lost health trails behind in pale ink so damage reads clearly.

var value := 1.0
var max_segments := 5
var color := UITheme.HEALTH
var _trail := 1.0


func _process(delta: float) -> void:
	_trail = move_toward(_trail, value, delta * (0.5 if _trail > value else 5.0))
	custom_minimum_size.x = maxf(62.0 * max_segments, 200.0)
	queue_redraw()


func _draw() -> void:
	var gap := 10.0
	var w := (size.x - gap * (max_segments - 1)) / max_segments
	for i in max_segments:
		var x := i * (w + gap)
		var seg_lo := float(i) / max_segments
		var seg_hi := float(i + 1) / max_segments
		var trail_fill := clampf((_trail - seg_lo) / (seg_hi - seg_lo), 0.0, 1.0)
		var fill := clampf((value - seg_lo) / (seg_hi - seg_lo), 0.0, 1.0)
		UIArt.brush_bar(self, Rect2(x, 2, w, size.y - 4), fill, color, trail_fill)
		if i < max_segments - 1:
			UIArt.diamond(self, Vector2(x + w + gap * 0.5, size.y * 0.5), 3.5, Color(UIArt.GOLD, 0.8))
