class_name LoadingScreen
extends CanvasLayer
## Covers world construction. Shows a rotating tip (localized).

const TIPS := ["TIP_1", "TIP_2", "TIP_3", "TIP_4", "TIP_5", "TIP_6"]

var _bar: ProgressBar
var _label: Label
var _bg: ColorRect


func _ready() -> void:
	layer = 50
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	add_child(root)
	_bg = ColorRect.new()
	_bg.color = Color(0.05, 0.063, 0.086)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_bg)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.custom_minimum_size = Vector2(560, 0)
	center.position = Vector2(-280, -80)
	root.add_child(center)
	var title := UITheme.label("VELA", 72, UITheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)
	_label = UITheme.label("", 20, UITheme.TEXT_DIM)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_label)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(560, 10)
	_bar.max_value = 1.0
	center.add_child(_bar)
	var tip := UITheme.label(tr(TIPS[randi() % TIPS.size()]), 20, UITheme.TEXT)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.custom_minimum_size = Vector2(560, 60)
	center.add_child(tip)


func set_progress(v: float, key: String) -> void:
	_bar.value = v
	_label.text = tr(key)


func finish() -> void:
	var t := create_tween()
	for c in get_children():
		t.parallel().tween_property(c, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)
