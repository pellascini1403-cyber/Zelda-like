extends Node
## Player preferences, persisted in user://settings.cfg (separate from saves).

const PATH := "user://settings.cfg"
const LANGUAGES := ["en", "es", "pt", "fr", "de", "ja", "ko", "zh"]

var values := {
	"music_volume": 0.7,
	"sfx_volume": 0.9,
	"ambience_volume": 0.8,
	"vibration": true,
	"camera_sensitivity": 1.0,
	"invert_y": false,
	"auto_camera": true,
	"quality": -1,           # -1 = auto-detect
	"dynamic_resolution": true,
	"fps_target": 60,
	"battery_saver": false,
	"language": "",          # "" = device language
	"text_scale": 1.0,
	"subtitles": true,
	"controls_scale": 1.0,
	"controls_opacity": 0.85,
	"left_handed": false,
	"analytics_consent": false,
	"show_fps": false,
}


func _ready() -> void:
	load_settings()
	apply_language()


func get_value(key: String) -> Variant:
	return values.get(key)


func set_value(key: String, value: Variant, save_now: bool = true) -> void:
	if values.get(key) == value:
		return
	values[key] = value
	if key == "language":
		apply_language()
	if save_now:
		save_settings()
	EventBus.settings_changed.emit()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in values:
		if cfg.has_section_key("settings", key):
			values[key] = cfg.get_value("settings", key)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value("settings", key, values[key])
	cfg.save(PATH)


func apply_language() -> void:
	var lang: String = values["language"]
	if lang == "":
		lang = OS.get_locale_language()
		if not lang in LANGUAGES:
			lang = "en"
	TranslationServer.set_locale(lang)


func current_language() -> String:
	return TranslationServer.get_locale().substr(0, 2)
