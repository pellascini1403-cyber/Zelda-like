class_name BossPlate
extends Control
## Boss health plate at the bottom of the screen: name, epithet, a long
## HUD bar with phase notches. Appears on
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
	HudArt.text(self, _tf, Vector2(x0, y - 16), name, nsz, a)
	var nw := _tf.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, nsz).x
	HudArt.text(self, _bf, Vector2(x0 + nw + 14, y - 18), sub, UITheme.fs(18), a)
	HudArt.bar(self, Rect2(Vector2(x0, y - 4), Vector2(w, 20)), boss.health.ratio(), a)
	for ph in boss.def.get("phases", []):
		var at := float(ph.get("at", 1.0))
		if at < 0.999:
			draw_line(Vector2(x0 + w * at, y - 4), Vector2(x0 + w * at, y + 16), Color(HudArt.BLACK, a), 2.0)
