class_name BossManager
extends Node3D
## Streams bosses (data/bosses.json): a boss exists only while the player is
## within SPAWN_DISTANCE of its arena and it has not been defeated
## (WorldState flag "boss_<ENTITY_ID>"). Far bosses cost nothing.

const SPAWN_DISTANCE := 180.0
const FREE_DISTANCE := 260.0

var gen: WorldGen
var spawner: SpawnDirector
var _live: Dictionary = {}   # boss id -> Boss
var _timer := 0.0


func _process(delta: float) -> void:
	if Game.player == null or not Game.is_playing():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.75
	var p := Game.player.global_position
	for id in DB.bosses:
		var d: Dictionary = DB.bosses[id]
		var center := arena_center(d)
		var dist := Vector2(p.x - center.x, p.z - center.z).length()
		var defeated := WorldState.flags.has("boss_" + String(d["entity"]))
		if _live.has(id):
			var b: Boss = _live[id]
			if not is_instance_valid(b):
				_live.erase(id)
			elif dist > FREE_DISTANCE and not b.engaged:
				b.queue_free()
				_live.erase(id)
		elif not defeated and dist < SPAWN_DISTANCE:
			_spawn(id, d, center)


func arena_center(d: Dictionary) -> Vector3:
	var a: Dictionary = d.get("arena", {})
	var c: Array = a.get("center", [0, 0])
	var y: float = a.get("y", gen.height(c[0], c[1]) if gen else 0.0)
	return Vector3(c[0], y, c[1])


func _spawn(id: StringName, d: Dictionary, center: Vector3) -> void:
	var type := DB.entity(StringName(d["entity"]))
	if type == null:
		push_warning("BossManager: unknown boss entity " + String(d["entity"]))
		return
	var b: Boss = Boss.new()
	b.setup_boss(d, center)
	var home: Array = d.get("arena", {}).get("home", [0, 0])
	var pos := center + Vector3(home[0], 0.6, home[1])
	b.setup(type, pos, "boss:" + String(id), "boss:" + String(id))
	spawner.creatures_root.add_child(b)
	_live[id] = b


func live_boss(id: StringName) -> Boss:
	return _live.get(id)
