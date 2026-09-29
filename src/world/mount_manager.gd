class_name MountManager
extends Node3D
## Mounts: wild herds (data/world.json "mounts") stream in near their
## pasture like any content; the player's tamed mount is persistent (saved
## position, survives streaming) and answers Strider Call.

const HERD_SPAWN := 170.0
const HERD_FREE := 240.0
const CALL_RANGE := 260.0

static var instance: MountManager

var gen: WorldGen
var spawner: SpawnDirector
var owned: Mount = null
var _herds: Dictionary = {}   # herd id -> Array[Mount]
var _timer := 0.0


func _ready() -> void:
	instance = self
	EventBus.game_loaded.connect(_restore)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	if Game.player == null or not Game.is_playing():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	if owned == null and WorldState.flags.has("mount_state"):
		_restore()
	var p := Game.player.global_position
	for h in DB.world.get("mounts", []):
		var id := String(h["id"])
		var c := Vector3(h["herd"][0], 0, h["herd"][1])
		var d := Vector2(p.x - c.x, p.z - c.z).length()
		if _herds.has(id):
			if d > HERD_FREE:
				for mt in _herds[id]:
					if is_instance_valid(mt) and mt != owned and (mt as Mount).rider == null:
						mt.queue_free()
				_herds.erase(id)
		elif d < HERD_SPAWN:
			var list: Array = []
			var n := int(h.get("count", 3)) - (1 if WorldState.flags.has("mount_" + id) else 0)
			for i in n:
				var a := TAU * i / maxf(n, 1)
				var sp := c + Vector3(cos(a), 0, sin(a)) * 6.0
				sp.y = gen.height(sp.x, sp.z) + 0.5
				list.append(_spawn(StringName(h["entity"]), sp, "herd:" + id))
			_herds[id] = list
	if owned and is_instance_valid(owned):
		WorldState.flags["mount_state"] = owned.save_state()


func _spawn(entity: StringName, pos: Vector3, group: String) -> Mount:
	var mt := Mount.new()
	mt.setup(DB.entity(entity), pos, "", group)
	spawner.creatures_root.add_child(mt)
	return mt


## A freshly tamed mount becomes the player's.
static func adopt(mt: Mount) -> void:
	if instance == null:
		return
	if instance.owned and is_instance_valid(instance.owned) and instance.owned != mt:
		instance.owned.queue_free()
	instance.owned = mt
	mt.group_id = "owned"
	# Leave the herd list so herd streaming never frees it.
	for id in instance._herds:
		(instance._herds[id] as Array).erase(mt)
	if mt.get_parent() != instance:
		mt.reparent(instance)


## Strider Call: the owned mount gallops over, or appears just out of sight
## when it is far away / not streamed.
static func call_mount(p: Player) -> bool:
	if instance == null or not WorldState.flags.has("mount_windstrider"):
		EventBus.toast.emit(TranslationServer.translate("TOAST_NO_MOUNT"))
		return false
	var mt := instance.owned
	if mt == null or not is_instance_valid(mt):
		instance._restore()
		mt = instance.owned
	if mt == null:
		return false
	Audio.play_ui(&"whistle", -2.0)
	if mt.global_position.distance_to(p.global_position) > CALL_RANGE:
		var back := p.global_position - p.facing_dir() * 28.0
		back.y = instance.gen.height(back.x, back.z) + 0.5
		mt.global_position = back
	mt.call_to(p.global_position)
	return true


func _restore() -> void:
	if not WorldState.flags.has("mount_state") or (owned and is_instance_valid(owned)):
		return
	var st: Dictionary = WorldState.flags["mount_state"]
	var pa: Array = st.get("pos", [0, 0, 0])
	var mt := Mount.new()
	mt.setup(DB.entity(&"MOUNT_WINDSTRIDER"), Vector3(pa[0], pa[1] + 0.5, pa[2]), "", "owned")
	add_child(mt)
	mt.tamed = true
	mt.mount_id = &"windstrider"
	mt.facing_yaw = float(st.get("yaw", 0.0))
	owned = mt
