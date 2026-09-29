extends Node
## Dynamic audio: music crossfades, weather/time ambience layers, pooled SFX.
##
## Sounds are referenced by id and resolved to res://assets/audio/<id>.wav
## (or .ogg). A missing file is silently skipped, so final audio can be
## dropped in later without code changes. See docs/ASSETS.md.

const AUDIO_DIR := "res://assets/audio/"
const SFX_POOL_3D := 16
const SFX_POOL_2D := 6
const MUSIC_FADE := 3.5

var _streams: Dictionary = {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: StringName = &""
var _ambience: Dictionary = {}  # id -> AudioStreamPlayer
var _pool_idx := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in SFX_POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.max_distance = 60.0
		p.unit_size = 6.0
		p.attenuation_filter_cutoff_hz = 8000.0
		add_child(p)
		_pool3d.append(p)
	for i in SFX_POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = &"UI"
		add_child(p)
		_pool2d.append(p)
	_music_a = _make_player(&"Music")
	_music_b = _make_player(&"Music")
	for id in [&"amb_wind", &"amb_rain", &"amb_day", &"amb_night"]:
		var p := _make_player(&"Ambience")
		p.stream = _get_stream(id)
		p.volume_db = -80.0
		_ambience[id] = p
	EventBus.settings_changed.connect(apply_volumes)
	apply_volumes()


func _setup_buses() -> void:
	for bus in ["Music", "SFX", "Ambience", "UI"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, &"Master")


func apply_volumes() -> void:
	_set_bus("Music", Settings.get_value("music_volume"))
	_set_bus("SFX", Settings.get_value("sfx_volume"))
	_set_bus("UI", Settings.get_value("sfx_volume"))
	_set_bus("Ambience", Settings.get_value("ambience_volume"))


func _set_bus(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _get_stream(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		var path: String = AUDIO_DIR + String(id) + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_streams[id] = stream
	return stream


# --- SFX ------------------------------------------------------------------------------
func play_at(id: StringName, pos: Vector3, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	var s := _get_stream(id)
	if s == null:
		return
	var p := _pool3d[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _pool3d.size()
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func play_ui(id: StringName, volume_db: float = -4.0) -> void:
	var s := _get_stream(id)
	if s == null:
		return
	for p in _pool2d:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = 1.0
			p.play()
			return


# --- Music ------------------------------------------------------------------------------
## Crossfades to a music track (no abrupt switches).
func play_music(id: StringName) -> void:
	if id == _music_current:
		return
	_music_current = id
	var incoming := _music_b if _music_a.playing and _music_a.volume_db > -40.0 else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	var s := _get_stream(id)
	if s:
		incoming.stream = s
		incoming.volume_db = -60.0
		incoming.play()
		create_tween().tween_property(incoming, "volume_db", -6.0, MUSIC_FADE)
	var t := create_tween()
	t.tween_property(outgoing, "volume_db", -80.0, MUSIC_FADE)
	t.tween_callback(outgoing.stop)


func current_music() -> StringName:
	return _music_current


# --- Ambience ------------------------------------------------------------------------------
## Called every frame by the world with target layer levels (0..1).
func set_ambience(levels: Dictionary, delta: float) -> void:
	for id in _ambience:
		var p: AudioStreamPlayer = _ambience[id]
		if p.stream == null:
			continue
		var target: float = levels.get(id, 0.0)
		var target_db := linear_to_db(maxf(target, 0.0001)) - 4.0
		p.volume_db = move_toward(p.volume_db, target_db, delta * 20.0)
		if target > 0.01 and not p.playing:
			p.play()
		elif target <= 0.01 and p.volume_db < -70.0 and p.playing:
			p.stop()


func stop_all() -> void:
	_music_current = &""
	for p in [_music_a, _music_b]:
		p.stop()
	for p: AudioStreamPlayer in _ambience.values():
		p.stop()
		p.volume_db = -80.0
