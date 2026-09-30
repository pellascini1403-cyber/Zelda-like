class_name HeartRow
extends Control
## Health as hearts (each heart = 20 HP), drawn with the definitive heart
## PNG. A lost heart is the same heart in black at 20 %; a partly lost one
## shows the lost part that way. Six hearts per row, like the reference.

const PER_ROW := 6
const ROW_PITCH := 38.0
## The hearts sit this far right of the status line under them.
const INSET := 14.0

var value := 1.0
var max_segments := 5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(_delta: float) -> void:
	var hs := HudArt.fit(HudArt.HEART, HudArt.HEART_W)
	var rows := maxi(ceili(max_segments / float(PER_ROW)), 1)
	custom_minimum_size = Vector2(INSET + HudArt.HEART_PITCH * (mini(max_segments, PER_ROW) - 1) + hs.x, ROW_PITCH * (rows - 1) + hs.y)
	queue_redraw()


func _draw() -> void:
	var tex := HudArt.HEART
	var hs := HudArt.fit(tex, HudArt.HEART_W)
	var ts := tex.get_size()
	for i in max_segments:
		var at := Vector2(INSET + HudArt.HEART_PITCH * (i % PER_ROW), ROW_PITCH * (i / PER_ROW))
		var fill := clampf(value * max_segments - i, 0.0, 1.0)
		if fill < 1.0:
			draw_texture_rect(tex, Rect2(at, hs), false, HudArt.SHADE)
		if fill > 0.0:
			draw_texture_rect_region(tex, Rect2(at, Vector2(hs.x * fill, hs.y)), Rect2(Vector2.ZERO, Vector2(ts.x * fill, ts.y)))
