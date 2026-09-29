extends Node
## Development tools. Active ONLY in debug builds (OS.is_debug_build()); in
## release exports this node stays inert: no overlay, no console, flags
## locked to false. Toggle with F1 / ` or a 3-finger tap on device.
##
## Console commands:
##   help | tp x z | tp <poi_id> | spawn <entity> [n] | give <item> [n]
##   weather <id> | time <hour> | god | stamina | map | kill | heal
##   quality <0-3> | ents (entity debug labels) | save | load | fps | touch

var enabled := false
var god_mode := false
var infinite_stamina := false
var show_entity_debug := false
var force_touch_ui := false

var _layer: CanvasLayer
var _overlay: Label
var _console: LineEdit
var _log: Label
var _show_perf := false
var _touch_count := 0


func _ready() -> void:
	enabled = OS.is_debug_build()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_overlay = Label.new()
	_overlay.position = Vector2(12, 130)
	_overlay.add_theme_font_size_override("font_size", 16)
	_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override("outline_size", 4)
	_layer.add_child(_overlay)
	_console = LineEdit.new()
	_console.visible = false
	_console.placeholder_text = "debug command (help)"
	_console.position = Vector2(12, 12)
	_console.custom_minimum_size = Vector2(620, 44)
	_console.text_submitted.connect(_on_submit)
	_layer.add_child(_console)
	_log = Label.new()
	_log.position = Vector2(12, 60)
	_log.add_theme_font_size_override("font_size", 16)
	_log.add_theme_color_override("font_outline_color", Color.BLACK)
	_log.add_theme_constant_override("outline_size", 4)
	_layer.add_child(_log)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_console"):
		_toggle_console()
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch:
		_touch_count += 1 if event.pressed else -1
		_touch_count = maxi(_touch_count, 0)
		if event.pressed and _touch_count >= 3:
			_toggle_console()


func _toggle_console() -> void:
	_console.visible = not _console.visible
	_show_perf = _console.visible or _show_perf
	if _console.visible:
		_console.grab_focus()
		InputRouter.gameplay_enabled = false
		InputRouter.release_mouse()
	else:
		_console.release_focus()
		InputRouter.gameplay_enabled = true


func _process(_delta: float) -> void:
	var show: bool = _show_perf or Settings.get_value("show_fps")
	_overlay.visible = show
	if not show:
		return
	var lines := PackedStringArray()
	lines.append("FPS %d  frame %.1f ms  target %d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Quality.target_fps()])
	lines.append("draw calls %d  prims %dk  objects %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	lines.append("mem static %.0f MB  video %.0f MB  tex %.0f MB" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0])
	lines.append("physics %.1f ms  bodies %d  nodes %d" % [
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	lines.append("quality %s  render scale %.2f  thermal %d" % [Quality.Level.keys()[Quality.level], get_viewport().scaling_3d_scale, Quality.thermal_state])
	var w := Game.world as GameWorld
	if w and w.streamer:
		lines.append("sectors %d  jobs %d  pois %d  fires %d" % [w.streamer.loaded_count(), w.streamer.pending_jobs(), w.pois.built_count(), FireSource.active_count])
		lines.append("AI full/reduced/dormant %d/%d/%d  %.2f ms" % [w.ai.counts[0], w.ai.counts[1], w.ai.counts[2], w.ai.last_tick_usec / 1000.0])
	if Game.player:
		var p := Game.player as Player
		lines.append("pos %.0f %.0f %.0f  %s  %s  %s" % [p.global_position.x, p.global_position.y, p.global_position.z, p.state_name(), p.region, Clock.period])
	if god_mode or infinite_stamina:
		lines.append("[GOD]" if god_mode else "" + (" [STAMINA]" if infinite_stamina else ""))
	_overlay.text = "\n".join(lines)


func _on_submit(text: String) -> void:
	_console.clear()
	var out := run(text)
	_log.text = out
	print("[debug] ", text, " -> ", out)


## Executes a command. Returns a result string (also used by automated tests).
func run(text: String) -> String:
	if not enabled:
		return "debug disabled"
	var a := text.strip_edges().split(" ", false)
	if a.is_empty():
		return ""
	var p := Game.player as Player
	var w := Game.world as GameWorld
	match a[0]:
		"help":
			return "tp x z | tp poi | spawn id [n] | give id [n] | weather id | time h | god | stamina | map | kill | heal | quality n | ents | save | load | fps | touch"
		"tp":
			if p == null:
				return "no player"
			var pos := Vector3.ZERO
			if a.size() >= 3:
				pos = Vector3(a[1].to_float(), 0, a[2].to_float())
			elif a.size() == 2:
				for poi in DB.world.get("pois", []):
					if poi["id"] == a[1]:
						pos = Vector3(poi["pos"][0], 0, poi["pos"][1]) + Vector3(0, 0, 12)
				if pos == Vector3.ZERO:
					return "unknown poi"
			pos.y = w.gen.height(pos.x, pos.z) + 3.0
			if p.vehicle:
				p.exit_vehicle(false)
			p.global_position = pos
			p.velocity = Vector3.ZERO
			return "teleported to %s" % pos
		"spawn":
			if a.size() < 2 or DB.entity(StringName(a[1])) == null:
				return "unknown entity. ids: " + ", ".join(DB.entities.keys().map(func(k: Variant) -> String: return String(k)))
			var n := a[2].to_int() if a.size() > 2 else 1
			for i in n:
				var sp := p.global_position + p.facing_dir() * (6.0 + i * 1.5) + Vector3(0, 1, 0)
				w.spawner.spawn_creature(StringName(a[1]), sp, "", "debug")
			return "spawned %d %s" % [n, a[1]]
		"give":
			if a.size() < 2 or DB.item(StringName(a[1])) == null:
				return "unknown item"
			var n := a[2].to_int() if a.size() > 2 else 1
			var added := PlayerData.inventory.add(StringName(a[1]), n)
			return "gave %d" % added
		"weather":
			if a.size() < 2:
				return "ids: " + ", ".join(DB.weather_types.keys().map(func(k: Variant) -> String: return String(k)))
			Weather.set_weather(StringName(a[1]), true)
			return "weather " + a[1]
		"time":
			Clock.set_time(a[1].to_float() if a.size() > 1 else 12.0)
			return "time %.1f" % Clock.hour
		"god":
			god_mode = not god_mode
			return "god %s" % god_mode
		"stamina":
			infinite_stamina = not infinite_stamina
			return "infinite stamina %s" % infinite_stamina
		"map":
			WorldState.map_revealed_all = not WorldState.map_revealed_all
			return "map reveal %s" % WorldState.map_revealed_all
		"kill":
			var n := 0
			for e in get_tree().get_nodes_in_group(&"enemies"):
				var info := DamageInfo.make(9999.0, p)
				info.kind = &"debug"
				e.take_damage(info)
				n += 1
			return "killed %d" % n
		"heal":
			PlayerData.health = PlayerData.max_health
			PlayerData.stamina = PlayerData.max_stamina
			return "healed"
		"quality":
			Quality.set_level(a[1].to_int() if a.size() > 1 else 1)
			return "quality %d" % Quality.level
		"ents":
			show_entity_debug = not show_entity_debug
			for c in get_tree().get_nodes_in_group(&"creatures"):
				(c as Creature).enable_debug_label(show_entity_debug)
			return "entity debug %s" % show_entity_debug
		"save":
			return "saved %s" % SaveSystem.save_game()
		"load":
			Game.start_game(true)
			return "reloading"
		"fps":
			_show_perf = not _show_perf
			return "perf overlay %s" % _show_perf
		"touch":
			force_touch_ui = not force_touch_ui
			return "touch ui %s" % force_touch_ui
	return "unknown command (help)"
