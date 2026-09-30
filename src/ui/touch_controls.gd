class_name TouchControls
extends Control
## Touch-first controls with true multi-touch (each finger is tracked by
## index; GUI mouse emulation is not relied upon).
##
## Left side: floating joystick (appears where the thumb lands; pushing past
## the ring = sprint). Right side: a compact cluster of contextual buttons
## that appear/disappear/relabel with the player's situation. Anywhere else:
## drag to look. Layout adapts to aspect ratio, safe area, left-handed mode
## and the control size/opacity accessibility settings.

const SPRINT_THRESHOLD := 1.12
const JOY_RADIUS := 96.0

class Btn:
	var action: String
	var label_key: String
	var center := Vector2.ZERO
	var radius := 60.0
	var visible := true
	var pressed := false
	var finger := -1
	var accent := false
	var badge := ""
	var alpha := 1.0

	func _init(a: String, key: String, r: float, is_accent: bool = false) -> void:
		action = a
		label_key = key
		radius = r
		accent = is_accent

	func hit(p: Vector2) -> bool:
		return visible and p.distance_to(center) <= radius * 1.15

var buttons: Dictionary = {}
var blockers: Array[Control] = []   # regions owned by other UI (menu buttons)
var _joy_finger := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_finger := -1
var _look_last := Vector2.ZERO
var _interact_key := ""
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UITheme.font()
	for b: Btn in [
		Btn.new("attack", "BTN_ATTACK", 78.0, true),
		Btn.new("jump", "BTN_JUMP", 60.0),
		Btn.new("dodge", "BTN_DODGE", 52.0),
		Btn.new("interact", "BTN_INTERACT", 54.0, true),
		Btn.new("block", "BTN_BLOCK", 46.0),
		Btn.new("lock_on", "BTN_LOCK", 40.0),
		Btn.new("use_item", "BTN_ITEM", 42.0),
		Btn.new("cycle_weapon", "BTN_WEAPON", 36.0),
		Btn.new("drop", "BTN_DROP", 48.0),
		Btn.new("ability", "BTN_ABILITY", 46.0, true),
		Btn.new("cycle_ability", "BTN_CYCLE", 26.0),
	]:
		buttons[b.action] = b
	EventBus.interact_prompt_changed.connect(func(k: String) -> void: _interact_key = k)
	get_viewport().size_changed.connect(_layout)
	EventBus.settings_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size_v := get_viewport_rect().size
	var m := UITheme.safe_margins(get_viewport())
	var s: float = Settings.get_value("controls_scale")
	# Scale with the short side so phones and tablets feel the same in hand.
	var k := clampf(size_v.y / 720.0, 0.8, 1.5) * s
	var left_handed: bool = Settings.get_value("left_handed")
	var base_x: float = size_v.x - m["right"] - 120.0 * k
	var base_y: float = size_v.y - m["bottom"] - 120.0 * k
	var place := {
		"attack": Vector2(0, 0),
		"jump": Vector2(-150, 40),
		"dodge": Vector2(10, -150),
		"interact": Vector2(-170, -120),
		"block": Vector2(-120, -250),
		"lock_on": Vector2(40, -265),
		"use_item": Vector2(-290, 30),
		"cycle_weapon": Vector2(-60, -60),
		"drop": Vector2(-150, -110),
		"ability": Vector2(-280, -95),
		"cycle_ability": Vector2(-330, -150),
	}
	for a in buttons:
		var b: Btn = buttons[a]
		var off: Vector2 = place[a] * k
		var c := Vector2(base_x + off.x, base_y + off.y)
		if left_handed:
			c.x = size_v.x - c.x
		b.center = c
		b.radius = {"attack": 78.0, "jump": 60.0, "dodge": 52.0, "interact": 54.0, "block": 46.0, "lock_on": 40.0, "use_item": 42.0, "cycle_weapon": 36.0, "drop": 48.0, "ability": 46.0, "cycle_ability": 26.0}[a] * k
	queue_redraw()


func _process(_delta: float) -> void:
	_update_context()
	queue_redraw()


## Which buttons exist right now, and what they say.
func _update_context() -> void:
	var p := Game.player as Player
	var playing := Game.is_playing() and p != null
	for b: Btn in buttons.values():
		b.visible = playing
	if not playing:
		return
	var st := p.state_name()
	var enemies_near := Game.in_combat or p.combat.lock_target_valid()
	var b_jump: Btn = buttons["jump"]
	var b_attack: Btn = buttons["attack"]
	b_jump.label_key = "BTN_JUMP"
	match st:
		&"climb":
			b_jump.label_key = "BTN_LEAP"
			buttons["attack"].visible = false
			buttons["dodge"].visible = false
			buttons["block"].visible = false
			buttons["use_item"].visible = false
			buttons["lock_on"].visible = false
			buttons["cycle_weapon"].visible = false
		&"glide":
			b_jump.label_key = "BTN_CLOSE"
			buttons["attack"].visible = false
			buttons["dodge"].visible = false
			buttons["block"].visible = false
			buttons["lock_on"].visible = false
			buttons["cycle_weapon"].visible = false
		&"swim":
			buttons["attack"].visible = false
			buttons["dodge"].visible = false
			buttons["block"].visible = false
			buttons["lock_on"].visible = false
			buttons["cycle_weapon"].visible = false
		&"air":
			if p.can_glide():
				b_jump.label_key = "BTN_GLIDE"
			buttons["dodge"].visible = false
			buttons["block"].visible = false
		&"dead":
			for b: Btn in buttons.values():
				b.visible = false
	if st != &"climb" and st != &"glide":
		buttons["drop"].visible = false
	elif st == &"glide":
		buttons["drop"].visible = false
	buttons["block"].visible = buttons["block"].visible and enemies_near
	buttons["lock_on"].visible = buttons["lock_on"].visible and (enemies_near or not get_tree().get_nodes_in_group(&"enemies").is_empty())
	var inter: Btn = buttons["interact"]
	inter.visible = inter.visible and _interact_key != "" and st == &"ground"
	inter.label_key = _interact_key
	# Quick item badge
	var qi := PlayerData.quick_item
	var ib: Btn = buttons["use_item"]
	if qi == &"" or DB.item(qi) == null:
		ib.visible = false
	else:
		ib.badge = str(PlayerData.inventory.count_of(qi))
	var w := PlayerData.weapon()
	b_attack.badge = ""
	var wb: Btn = buttons["cycle_weapon"]
	wb.visible = wb.visible and PlayerData.inventory.in_category(&"weapon").size() > 1
	if w and not w.is_heirloom() and w.durability_ratio() <= 0.25:
		b_attack.badge = "!"
	var ab: Btn = buttons["ability"]
	var has_ab := p.abilities != null and p.abilities.selected != &""
	ab.visible = ab.visible and has_ab and st != &"dead"
	buttons["cycle_ability"].visible = ab.visible and p.abilities.unlocked().size() > 1
	if st == &"drive" and p.vehicle:
		for key in ["dodge", "block", "cycle_weapon", "drop", "use_item"]:
			buttons[key].visible = false
		var armed := p.vehicle.def.has("weapon")
		b_attack.visible = armed
		b_attack.label_key = "BTN_FIRE"
		buttons["lock_on"].visible = armed and enemies_near
		b_jump.visible = float(p.vehicle.h.get("jump", 0.0)) > 0.0 and p.vehicle.mode == &"land_mode"
		inter.visible = true
		inter.label_key = "PROMPT_EXIT_VEHICLE"
	else:
		b_attack.label_key = "BTN_ATTACK"
	if st == &"ride":
		for key in ["attack", "dodge", "block", "lock_on", "cycle_weapon", "drop", "use_item"]:
			buttons[key].visible = false
		inter.visible = true
		inter.label_key = "PROMPT_DISMOUNT"
		b_jump.label_key = "BTN_JUMP"
	var alpha: float = Settings.get_value("controls_opacity")
	for b: Btn in buttons.values():
		b.alpha = alpha


func _input(event: InputEvent) -> void:
	if not Game.is_playing():
		_release_all()
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_on_down(e.index, e.position)
		else:
			_on_up(e.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_finger:
			_joy_pos = d.position
			_update_joy()
		elif d.index == _look_finger:
			var delta := d.position - _look_last
			_look_last = d.position
			InputRouter.add_look(delta * 0.22)


func _on_down(index: int, pos: Vector2) -> void:
	for blk in blockers:
		if is_instance_valid(blk) and blk.is_visible_in_tree() and blk.get_global_rect().has_point(pos):
			return
	for b: Btn in buttons.values():
		if b.hit(pos) and b.finger == -1:
			b.finger = index
			b.pressed = true
			Input.action_press(b.action)
			InputRouter.vibrate(8, 0.2)
			get_viewport().set_input_as_handled()
			return
	var left_handed: bool = Settings.get_value("left_handed")
	var on_joy_side := pos.x < get_viewport_rect().size.x * 0.45 if not left_handed else pos.x > get_viewport_rect().size.x * 0.55
	if on_joy_side and _joy_finger == -1:
		_joy_finger = index
		_joy_origin = pos
		_joy_pos = pos
		_update_joy()
	elif _look_finger == -1:
		_look_finger = index
		_look_last = pos
	get_viewport().set_input_as_handled()


func _on_up(index: int) -> void:
	for b: Btn in buttons.values():
		if b.finger == index:
			b.finger = -1
			b.pressed = false
			Input.action_release(b.action)
	if index == _joy_finger:
		_joy_finger = -1
		InputRouter.touch_move = Vector2.ZERO
		InputRouter.touch_sprint = false
	if index == _look_finger:
		_look_finger = -1


func _update_joy() -> void:
	var r := JOY_RADIUS * clampf(get_viewport_rect().size.y / 720.0, 0.8, 1.5)
	var v := (_joy_pos - _joy_origin) / r
	InputRouter.touch_sprint = v.length() > SPRINT_THRESHOLD
	# Follow the thumb if it drifts far (floating base).
	if v.length() > 1.6:
		_joy_origin = _joy_pos - v.normalized() * r * 1.6
		v = v.normalized() * 1.6
	var out := v.limit_length(1.0)
	InputRouter.touch_move = Vector2(out.x, -out.y)


func _release_all() -> void:
	for b: Btn in buttons.values():
		if b.pressed:
			Input.action_release(b.action)
		b.pressed = false
		b.finger = -1
	_joy_finger = -1
	_look_finger = -1
	InputRouter.touch_move = Vector2.ZERO
	InputRouter.touch_sprint = false


const GLYPHS := {
	"attack": "attack", "jump": "jump", "dodge": "dodge", "interact": "interact", "block": "guard",
	"lock_on": "lock", "use_item": "item", "cycle_weapon": "weapon", "drop": "drop", "cycle_ability": "dodge",
}


func _draw() -> void:
	if not InputRouter.using_touch and not OS.has_feature("mobile") and not Debug.force_touch_ui:
		return
	var k := clampf(get_viewport_rect().size.y / 720.0, 0.8, 1.5)
	var p := Game.player as Player
	for b: Btn in buttons.values():
		if not b.visible:
			continue
		var r := b.radius * (0.92 if b.pressed else 1.0)
		HudArt.disc(self, b.center, r, b.pressed, b.alpha)
		var ink := Color(HudArt.WHITE, b.alpha)
		if b.action == "ability" and p and p.abilities:
			var d: Dictionary = DB.abilities.get(p.abilities.selected, {})
			UIArt.glyph(self, String(d.get("glyph", "")), b.center, r * 1.05, ink)
			HudArt.cooldown(self, b.center, r, p.abilities.cooldown_ratio(p.abilities.selected))
		elif b.action == "interact" or (b.action == "jump" and b.label_key != "BTN_JUMP"):
			# Contextual verbs stay words (engraved face), everything else is a glyph.
			var text := tr(b.label_key)
			var fsz := int(clampf(r * 0.34, 13, 26))
			var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz).x
			HudArt.text(self, _font, b.center + Vector2(-tw * 0.5, fsz * 0.35), text, fsz, b.alpha)
		else:
			UIArt.glyph(self, GLYPHS.get(b.action, ""), b.center, r * (0.95 if b.action != "attack" else 0.85), ink)
		if b.badge != "":
			var bp := b.center + Vector2(b.radius * 0.7, -b.radius * 0.7)
			draw_circle(bp, 14 * k, HudArt.CELESTE if b.badge == "!" else HudArt.BLACK)
			var bw := _font.get_string_size(b.badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 17).x
			draw_string(_font, bp + Vector2(-bw * 0.5, 6), b.badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 17, HudArt.BLACK if b.badge == "!" else HudArt.WHITE)
	# Joystick
	var r := JOY_RADIUS * k
	if _joy_finger >= 0:
		var sprint := InputRouter.touch_sprint
		HudArt.disc(self, _joy_origin, r, sprint)
		var knob := _joy_origin + (_joy_pos - _joy_origin).limit_length(r)
		HudArt.disc(self, knob, r * 0.42, sprint)
	else:
		# Hint where the stick lives
		var m := UITheme.safe_margins(get_viewport())
		var hint := Vector2(m["left"] + r * 1.4, get_viewport_rect().size.y - m["bottom"] - r * 1.4)
		if Settings.get_value("left_handed"):
			hint.x = get_viewport_rect().size.x - hint.x
		draw_circle(hint, r, HudArt.SHADE)
