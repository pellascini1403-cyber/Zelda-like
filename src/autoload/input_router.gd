extends Node
## Single source of truth for player intent, whatever the device.
##
## Touch controls, keyboard/mouse and gamepads all end up as the same InputMap
## actions + a move vector + a look delta. Gameplay never reads raw input.

const ACTIONS := {
	"move_forward": [KEY_W, JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [KEY_S, JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [KEY_A, JOY_AXIS_LEFT_X, -1.0],
	"move_right": [KEY_D, JOY_AXIS_LEFT_X, 1.0],
	"look_up": [KEY_UP, JOY_AXIS_RIGHT_Y, -1.0],
	"look_down": [KEY_DOWN, JOY_AXIS_RIGHT_Y, 1.0],
	"look_left": [KEY_LEFT, JOY_AXIS_RIGHT_X, -1.0],
	"look_right": [KEY_RIGHT, JOY_AXIS_RIGHT_X, 1.0],
}
const BUTTONS := {
	"jump": [KEY_SPACE, JOY_BUTTON_A],
	"attack": [KEY_J, JOY_BUTTON_X],
	"dodge": [KEY_Q, JOY_BUTTON_B],
	"interact": [KEY_E, JOY_BUTTON_Y],
	"sprint": [KEY_SHIFT, JOY_BUTTON_LEFT_STICK],
	"block": [KEY_K, JOY_BUTTON_LEFT_SHOULDER],
	"lock_on": [KEY_TAB, JOY_BUTTON_RIGHT_STICK],
	"use_item": [KEY_R, JOY_BUTTON_RIGHT_SHOULDER],
	"cycle_weapon": [KEY_F, JOY_BUTTON_DPAD_RIGHT],
	"cycle_item": [KEY_G, JOY_BUTTON_DPAD_LEFT],
	"drop": [KEY_C, JOY_BUTTON_DPAD_DOWN],
	"menu": [KEY_ESCAPE, JOY_BUTTON_START],
	"map": [KEY_M, JOY_BUTTON_BACK],
	"inventory": [KEY_I, JOY_BUTTON_DPAD_UP],
	"debug_console": [KEY_F1, -1],
	"ability": [KEY_V, JOY_BUTTON_MISC1],
	"cycle_ability": [KEY_B, -1],
}

var touch_move := Vector2.ZERO
var touch_sprint := false
var _look_delta := Vector2.ZERO
var using_touch := false
var gameplay_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()
	using_touch = DisplayServer.is_touchscreen_available() and OS.has_feature("mobile")


func _register_actions() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		var k := InputEventKey.new()
		k.physical_keycode = ACTIONS[action][0]
		InputMap.action_add_event(action, k)
		var j := InputEventJoypadMotion.new()
		j.axis = ACTIONS[action][1]
		j.axis_value = ACTIONS[action][2]
		InputMap.action_add_event(action, j)
	for action in BUTTONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var k := InputEventKey.new()
		k.physical_keycode = BUTTONS[action][0]
		InputMap.action_add_event(action, k)
		if BUTTONS[action][1] >= 0:
			var jb := InputEventJoypadButton.new()
			jb.button_index = BUTTONS[action][1]
			InputMap.action_add_event(action, jb)
	# Mouse bindings for desktop testing
	_add_mouse("attack", MOUSE_BUTTON_LEFT)
	_add_mouse("block", MOUSE_BUTTON_RIGHT)
	_add_mouse("lock_on", MOUSE_BUTTON_MIDDLE)
	var ctrl := InputEventKey.new()
	ctrl.physical_keycode = KEY_CTRL
	InputMap.action_add_event("dodge", ctrl)
	# Gamepad triggers: right = ability, left = cycle ability.
	for pair in [["ability", JOY_AXIS_TRIGGER_RIGHT], ["cycle_ability", JOY_AXIS_TRIGGER_LEFT]]:
		var tj := InputEventJoypadMotion.new()
		tj.axis = pair[1]
		tj.axis_value = 1.0
		InputMap.action_add_event(pair[0], tj)
	var grave := InputEventKey.new()
	grave.physical_keycode = KEY_QUOTELEFT
	InputMap.action_add_event("debug_console", grave)


func _add_mouse(action: String, button: MouseButton) -> void:
	var m := InputEventMouseButton.new()
	m.button_index = button
	InputMap.action_add_event(action, m)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		using_touch = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		using_touch = false
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look(event.relative * 0.15)
	if event is InputEventMouseButton and event.pressed and not using_touch and gameplay_enabled and Game.is_playing():
		if not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Movement in screen space: x = right, y = forward (up on stick).
func get_move() -> Vector2:
	if not gameplay_enabled:
		return Vector2.ZERO
	var v := touch_move
	var k := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	if k.length() > v.length():
		v = k
	return v.limit_length(1.0)


func wants_sprint() -> bool:
	return gameplay_enabled and (touch_sprint or Input.is_action_pressed("sprint"))


## Called by touch drag / mouse. Units: degrees.
func add_look(delta_deg: Vector2) -> void:
	_look_delta += delta_deg


## Camera consumes accumulated look input once per frame.
func consume_look(delta: float) -> Vector2:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down") * 160.0 * delta
	var out := _look_delta + stick
	_look_delta = Vector2.ZERO
	var sens: float = Settings.get_value("camera_sensitivity")
	out *= sens
	if Settings.get_value("invert_y"):
		out.y = -out.y
	return out if gameplay_enabled else Vector2.ZERO


func release_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func vibrate(ms: int = 30, amplitude: float = 0.5) -> void:
	if Settings.get_value("vibration") and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)
