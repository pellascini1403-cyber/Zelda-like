class_name WorldStreamer
extends Node3D
## Streams terrain sectors around a focus node.
##
## * Desired LOD per sector from ring distance (radii from Quality settings).
## * Sector data is built on WorkerThreadPool; results are applied on the main
##   thread with a per-frame budget so streaming never spikes a frame.
## * Old LOD stays visible until the new one is ready: no holes.
## * Sectors beyond the outer ring are freed; HorizonTiles cover the distance
##   and are told which sectors are covered so they can hide underneath.

signal initial_area_ready
signal sector_coverage_changed(coord: Vector2i, covered: bool)


var focus: Node3D
var chunks: Dictionary = {}           # Vector2i -> TerrainChunk
var _jobs: Dictionary = {}            # Vector2i -> task id
var _queue: Array = []                # [dist², coord, lod] sorted nearest first
var _max_jobs := 3
var _results: Array = []
var _mutex := Mutex.new()
var _last_center := Vector2i(999999, 999999)
var _world_data: Dictionary
var _initial_pending := true
var _refresh_timer := 0.0

var lod0_radius := 2
var lod1_radius := 3
var veg_density := 1.0
var veg_distance := 55.0


func _ready() -> void:
	_world_data = DB.world
	# Leave cores for the main and render threads.
	_max_jobs = clampi(OS.get_processor_count() - 2, 2, 6)
	_apply_quality()
	EventBus.quality_changed.connect(func(_l: int) -> void:
		_apply_quality()
		_last_center = Vector2i(999999, 999999))


func _apply_quality() -> void:
	var q := Quality.current()
	lod0_radius = q["lod0_radius"]
	lod1_radius = q["lod1_radius"]
	veg_density = q["vegetation_density"]
	veg_distance = q["vegetation_distance"]
	var grass := WorldMaterials.get_mat(&"grass") as ShaderMaterial
	grass.set_shader_parameter("fade_end", veg_distance * 0.95)
	grass.set_shader_parameter("fade_start", veg_distance * 0.65)


func _exit_tree() -> void:
	for id in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(id)
	_jobs.clear()


func focus_coord() -> Vector2i:
	var p := focus.global_position if focus else Vector3.ZERO
	return Vector2i(floori(p.x / ChunkBuilder.CHUNK_SIZE), floori(p.z / ChunkBuilder.CHUNK_SIZE))


func _process(delta: float) -> void:
	if focus == null:
		return
	_collect_finished_jobs()
	_apply_results()
	_start_queued()
	_refresh_timer -= delta
	var center := focus_coord()
	if center != _last_center or _refresh_timer <= 0.0:
		_last_center = center
		_refresh_timer = 0.5
		_refresh(center)
	if _initial_pending and _area_ready(center):
		_initial_pending = false
		initial_area_ready.emit()


func desired_lod(c: Vector2i, center: Vector2i) -> int:
	var d := maxi(absi(c.x - center.x), absi(c.y - center.y))
	if d <= lod0_radius:
		return 0
	if d <= lod1_radius:
		return 1
	return -1


func _refresh(center: Vector2i) -> void:
	var wanted: Array = []
	var limit := int(WorldGen.WORLD_HALF / ChunkBuilder.CHUNK_SIZE)
	for z in range(center.y - lod1_radius, center.y + lod1_radius + 1):
		for x in range(center.x - lod1_radius, center.x + lod1_radius + 1):
			if x < -limit or z < -limit or x >= limit or z >= limit:
				continue
			var c := Vector2i(x, z)
			var lod := desired_lod(c, center)
			if lod < 0:
				continue
			var ch: TerrainChunk = chunks.get(c)
			if ch == null:
				ch = TerrainChunk.new()
				ch.setup(c)
				ch.gameplay_ready.connect(_on_gameplay_ready)
				ch.gameplay_released.connect(_on_gameplay_released)
				add_child(ch)
				chunks[c] = ch
			if ch.lod != lod and ch.pending_lod != lod:
				wanted.append([center.distance_squared_to(c), c, lod])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_queue = wanted
	_start_queued()
	# Unload sectors that left the view (with 1 ring of hysteresis).
	for c: Vector2i in chunks.keys():
		var d := maxi(absi(c.x - center.x), absi(c.y - center.y))
		if d > lod1_radius + 1 and not _jobs.has(c):
			var ch: TerrainChunk = chunks[c]
			if ch.lod >= 0:
				sector_coverage_changed.emit(c, false)
			ch.release_gameplay()
			ch.queue_free()
			chunks.erase(c)


## Keeps the worker pool busy every frame (nearest sectors first).
func _start_queued() -> void:
	while _jobs.size() < _max_jobs and not _queue.is_empty():
		var w: Array = _queue.pop_front()
		var ch: TerrainChunk = chunks.get(w[1])
		if ch != null and ch.lod != w[2] and ch.pending_lod != w[2]:
			_start_job(w[1], w[2])


func _start_job(c: Vector2i, lod: int) -> void:
	if _jobs.has(c):
		return
	var ch: TerrainChunk = chunks[c]
	ch.pending_lod = lod
	var density := veg_density
	var world := _world_data
	var id := WorkerThreadPool.add_task(func() -> void:
		var gen := WorldGen.from_world_data(world)
		var data := ChunkBuilder.build(gen, c.x, c.y, lod, density)
		_mutex.lock()
		_results.append(data)
		_mutex.unlock(), false, "chunk")
	_jobs[c] = id


func _collect_finished_jobs() -> void:
	for c: Vector2i in _jobs.keys():
		var id: int = _jobs[c]
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_jobs.erase(c)


func _apply_results() -> void:
	var budget_usec := 3500 if _initial_pending else 1800
	var start := Time.get_ticks_usec()
	while true:
		_mutex.lock()
		var data: Variant = null if _results.is_empty() else _results.pop_front()
		_mutex.unlock()
		if data == null:
			break
		var c := Vector2i(data["cx"], data["cz"])
		var ch: TerrainChunk = chunks.get(c)
		if ch != null and ch.pending_lod == data["lod"]:
			ch.pending_lod = -1
			var was_covered := ch.lod >= 0
			ch.apply(data, veg_distance)
			if not was_covered:
				sector_coverage_changed.emit(c, true)
		if Time.get_ticks_usec() - start > budget_usec:
			break


func _area_ready(center: Vector2i) -> bool:
	for z in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var ch: TerrainChunk = chunks.get(Vector2i(x, z))
			if ch == null or not ch.is_collision_ready():
				return false
	return true


## True when the ground below `pos` has collision (safe to enable physics).
func has_collision_at(pos: Vector3) -> bool:
	var c := Vector2i(floori(pos.x / ChunkBuilder.CHUNK_SIZE), floori(pos.z / ChunkBuilder.CHUNK_SIZE))
	var ch: TerrainChunk = chunks.get(c)
	return ch != null and ch.is_collision_ready()


func loaded_count() -> int:
	return chunks.size()


func pending_jobs() -> int:
	return _jobs.size() + _queue.size()


# --- Gameplay content hand-off ------------------------------------------------------
signal sector_gameplay_ready(chunk: TerrainChunk, slots: Array)
signal sector_gameplay_released(chunk: TerrainChunk)


func _on_gameplay_ready(chunk: TerrainChunk, slots: Array) -> void:
	sector_gameplay_ready.emit(chunk, slots)


func _on_gameplay_released(chunk: TerrainChunk) -> void:
	sector_gameplay_released.emit(chunk)
