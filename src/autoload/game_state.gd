extends Node
## High level game flow + shared runtime references.
##
## Owns: scene transitions, pause, combat flag, hit-stop / slow motion.
## Other systems reach the player / world through here rather than paths.

enum State { BOOT, MENU, LOADING, PLAYING, PAUSED, DEAD }

const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

var state: int = State.BOOT
var player: Node3D
var camera_rig: Node3D
var world: Node3D
var in_combat := false
var in_cutscene := false
## Set by the main menu: continue from save or start new.
var load_on_start := true

var _slowmo_until := 0.0
var _combat_enemies: Dictionary = {}


## < 1 while the Stillness ability is active: AI and hostile projectiles
## advance slower, the player keeps full speed.
var enemy_time_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_playing() -> bool:
	return state == State.PLAYING


func start_game(from_save: bool) -> void:
	load_on_start = from_save
	state = State.LOADING
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)


func return_to_menu() -> void:
	if state == State.PLAYING or state == State.PAUSED:
		SaveSystem.save_game()
	get_tree().paused = false
	Engine.time_scale = 1.0
	state = State.MENU
	player = null
	world = null
	camera_rig = null
	get_tree().change_scene_to_file(MENU_SCENE)


func set_paused(p: bool) -> void:
	if state != State.PLAYING and state != State.PAUSED:
		return
	state = State.PAUSED if p else State.PLAYING
	get_tree().paused = p
	InputRouter.gameplay_enabled = not p
	if p:
		InputRouter.release_mouse()
	EventBus.menu_toggled.emit(p)


# --- Combat flag (driven by AI) ------------------------------------------------------
func register_aggro(enemy: Node, aggro: bool) -> void:
	if aggro:
		_combat_enemies[enemy.get_instance_id()] = true
	else:
		_combat_enemies.erase(enemy.get_instance_id())
	var now := not _combat_enemies.is_empty()
	if now != in_combat:
		in_combat = now
		EventBus.combat_state_changed.emit(in_combat)


func clear_aggro() -> void:
	_combat_enemies.clear()
	if in_combat:
		in_combat = false
		EventBus.combat_state_changed.emit(false)


# --- Time effects -------------------------------------------------------------------------
## Brief freeze on impact. Makes hits feel heavy.
func hitstop(duration: float = 0.06, scale: float = 0.05) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() / 1000.0 < _slowmo_until:
		return
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if Time.get_ticks_msec() / 1000.0 >= _slowmo_until:
		Engine.time_scale = 1.0


## Slow motion window (perfect dodge).
func slow_motion(scale: float, duration: float) -> void:
	_slowmo_until = Time.get_ticks_msec() / 1000.0 + duration
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if Time.get_ticks_msec() / 1000.0 >= _slowmo_until - 0.01:
		Engine.time_scale = 1.0


func _notification(what: int) -> void:
	# Mobile: the OS may kill a backgrounded app at any time — save now.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state == State.PLAYING or state == State.PAUSED:
			SaveSystem.save_game()
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING and OS.has_feature("mobile"):
			set_paused(true)
