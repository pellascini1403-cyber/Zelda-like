extends Node
## Save / load with autosave, atomic writes and a rolling backup.
##
## Format: JSON (versioned) in user://. Written to a temp file then renamed,
## so a crash or the OS killing the app mid-write never corrupts the save.
## If the main file is unreadable the backup is used.

const SAVE_VERSION := 1
const SLOT_PATH := "user://save_0.json"
const BACKUP_PATH := "user://save_0.bak.json"
const TMP_PATH := "user://save_0.tmp.json"
const AUTOSAVE_INTERVAL := 90.0

var playtime := 0.0
var _autosave_timer := AUTOSAVE_INTERVAL
var _loaded: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not Game.is_playing():
		return
	playtime += delta
	_autosave_timer -= delta
	# Never autosave mid-fight: the snapshot could be a bad place to resume.
	if _autosave_timer <= 0.0 and not Game.in_combat and not Game.in_cutscene:
		_autosave_timer = AUTOSAVE_INTERVAL
		save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SLOT_PATH) or FileAccess.file_exists(BACKUP_PATH)


func save_game() -> bool:
	if Game.player == null:
		return false
	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"playtime": playtime,
		"player": Game.player.save_state(),
		"player_data": PlayerData.save_state(),
		"world": WorldState.save_state(),
		"clock": Clock.save_state(),
		"weather": Weather.save_state(),
	}
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot write " + TMP_PATH)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(SLOT_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			dir.remove(BACKUP_PATH.get_file())
		dir.rename(SLOT_PATH.get_file(), BACKUP_PATH.get_file())
	dir.rename(TMP_PATH.get_file(), SLOT_PATH.get_file())
	_autosave_timer = AUTOSAVE_INTERVAL
	EventBus.game_saved.emit()
	return true


## Reads the save into memory. Systems pull their part via `section()` when
## the world is ready (so loading is independent from scene construction).
func read_save() -> bool:
	for path in [SLOT_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.has("version"):
			_loaded = _migrate(parsed)
			return true
		push_warning("SaveSystem: corrupt save at " + path + ", trying backup")
	_loaded = {}
	return false


func section(key: String) -> Dictionary:
	return _loaded.get(key, {})


func has_loaded() -> bool:
	return not _loaded.is_empty()


## Applies global (non-scene) state. The Player applies its own section.
func apply_loaded_globals() -> void:
	if _loaded.is_empty():
		return
	playtime = _loaded.get("playtime", 0.0)
	PlayerData.load_state(section("player_data"))
	WorldState.load_state(section("world"))
	Clock.load_state(section("clock"))
	Weather.load_state(section("weather"))
	EventBus.game_loaded.emit()


func new_game() -> void:
	_loaded = {}
	playtime = 0.0
	WorldState.reset()
	PlayerData.reset_new_game()
	Clock.load_state({"hour": 7.2, "day": 1})
	Weather.set_weather(&"clear", true)


func delete_save() -> void:
	for path in [SLOT_PATH, BACKUP_PATH, TMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Upgrades older save formats in place. Add a step per version bump.
func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v > SAVE_VERSION:
		push_warning("SaveSystem: save from a newer build (v%d)" % v)
	return d
