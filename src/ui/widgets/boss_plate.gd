class_name BossPlate
extends Control
## Boss health plate at the bottom of the screen: engraved name, epithet,
## long brush bar with phase notches and scroll ornaments. Appears on
## engagement, fades out on defeat or disengage.

var boss: Boss = null
var _alpha := 0.0
var _trail := 1.0
var _tf: Font
var _bf: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tf = UITheme.title_font()
	_bf = UITheme.font()
	EventBus.boss_engaged.connect(func(_id: StringName, node: Node3D) -> void:
		boss = node as Boss
		_trail = 1.0)
	EventBus.boss_disengaged.connect(func(_id: StringName) -> void: boss = null)
	EventBus.boss_defeated.connect(func(_id: StringName) -> void: boss = null)


func _process(delta: float) -> void:
	var want := 1.0 if boss != null and is_instance_valid(boss) and boss.engaged else 0.0
	_alpha = move_toward(_alpha, want, delta * 2.0)
	if boss and is_instance_valid(boss):
		_trail = move_toward(_trail, boss.health.ratio(), delta * (0.35 if _trail > boss.health.ratio() else 3.0))
	if _alpha > 0.0:
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01 or boss == null or not is_instance_valid(boss):
		return
	var vs := get_viewport_rect().size
	var m := UITheme.safe_margins(get_viewport())
	var w := minf(vs.x * 0.56, 820.0)
	var x0 := vs.x * 0.5 - w * 0.5
	var y: float = vs.y - m["bottom"] - 58.0
	var a := _alpha
	var name := tr(boss.type.name_key)
	var sub := tr(boss.def.get("title_key", ""))
	var nsz := UITheme.fs(28)
	draw_string_outline(_tf, Vector2(x0, y - 16), name, HORIZONTAL_ALIGNMENT_LEFT, -1, nsz, 6, Color(0, 0, 0, 0.6 * a))
	draw_string(_tf, Vector2(x0, y - 16), name, HORIZONTAL_ALIGNMENT_LEFT, -1, nsz, Color(UIArt.PAPER, a))
	var nw := _tf.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, nsz).x
	draw_string(_bf, Vector2(x0 + nw + 14, y - 18), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.fs(18), Color(UIArt.GOLD, 0.85 * a))
	var bar := Rect2(Vector2(x0, y - 4), Vector2(w, 20))
	UIArt.brush_bar(self, bar, boss.health.ratio(), Color(UIArt.CINNABAR, a), _trail)
	draw_line(Vector2(x0 - 16, y + 22), Vector2(x0 + w + 16, y + 22), Color(UIArt.GOLD, 0.6 * a), 1.2)
	UIArt.scroll_corner(self, Vector2(x0 - 16, y + 22), 14, Vector2(1, -1), Color(UIArt.GOLD, 0.8 * a))
	UIArt.scroll_corner(self, Vector2(x0 + w + 16, y + 22), 14, Vector2(-1, -1), Color(UIArt.GOLD, 0.8 * a))
	for ph in boss.def.get("phases", []):
		var at := float(ph.get("at", 1.0))
		if at < 0.999:
			UIArt.diamond(self, Vector2(x0 + w * at, y + 6), 5.0, Color(UIArt.GOLD, a))
