class_name VehicleManager
extends Node3D
## Premium vehicles in the open world. They are never parked around the map:
## the player's equipped vehicle appears only when summoned (Vantrel Call,
## Garage), one at a time, on a safe spot next to the player, and is put
## away when left far behind. Also the restoration rules (Garage bench).
##
## Summon rules: owned + equipped; not during a boss fight; not while
## climbing/gliding; swimming only for the amphibious capsule; the spot must
## be walkable (slope), dry (unless amphibious), inside loaded collision and
## clear of rocks, walls, props, creatures and NPCs.

const DESPAWN_DIST := 320.0
const SPOT_OFFSETS := [Vector3(3.2, 0, 0.5), Vector3(-3.2, 0, 0.5), Vector3(0, 0, -4.5), Vector3(0, 0, 4.5),
	Vector3(4.5, 0, -3.0), Vector3(-4.5, 0, -3.0), Vector3(5.5, 0, 3.5), Vector3(-5.5, 0, 3.5)]

static var instance: VehicleManager

var gen: WorldGen
var active: Vehicle = null
var boss_active := false
var _timer := 0.0
var _night := false
var _unveil_pending: StringName = &""


func _ready() -> void:
	instance = self
	EventBus.boss_engaged.connect(func(_id: StringName, _n: Node3D) -> void:
		boss_active = true
		# Arena rule: machines stay outside boss fights.
		if Game.player and (Game.player as Player).vehicle:
			(Game.player as Player).exit_vehicle(false)
			EventBus.toast.emit(tr("TOAST_VEHICLE_BOSS")))
	EventBus.vehicle_acquired.connect(_on_acquired)
	EventBus.boss_disengaged.connect(func(_id: StringName) -> void: boss_active = false)
	EventBus.boss_defeated.connect(func(_id: StringName) -> void: boss_active = false)


func _exit_tree() -> void:
	if instance == self:
		instance = null


## Obtaining a machine is an event: fanfare, title card, and it rolls out
## beside you as soon as you are back in the world.
func _on_acquired(id: StringName, _source: String) -> void:
	var d: Dictionary = DB.vehicles.get(id, {})
	Audio.play_ui(&"vehicle_unlock", -2.0)
	EventBus.title_card.emit(tr(String(d.get("name_key", ""))), tr("VEH_ACQUIRED"))
	_unveil_pending = id


func _process(delta: float) -> void:
	if _unveil_pending != &"" and Game.is_playing() and not get_tree().paused and Game.player:
		var p := Game.player as Player
		if p.state_name() in [&"ground"] and summon_block_reason(p) == "":
			PlayerData.equip_vehicle(_unveil_pending)
			_unveil_pending = &""
			summon(p)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	var night := Clock.is_night()
	if night != _night:
		_night = night
		VehicleVisual.set_night(night)
	if active and is_instance_valid(active):
		active.visual.set_headlamp(night and active.driver != null)
		if Game.player and active.driver == null and active.global_position.distance_to(Game.player.global_position) > DESPAWN_DIST:
			put_away()


## Why the equipped vehicle can't come right now ("" = it can).
func summon_block_reason(p: Player) -> String:
	var id := PlayerData.vehicle_equipped
	if id == &"" or not PlayerData.owns_vehicle(id):
		return "TOAST_NO_VEHICLE"
	if boss_active:
		return "TOAST_VEHICLE_BOSS"
	if p.vehicle or p.mount:
		return "TOAST_VEHICLE_BUSY"
	var st := p.state_name()
	if st in [&"climb", &"glide", &"dead", &"busy", &"gust"]:
		return "TOAST_VEHICLE_BUSY"
	var def: Dictionary = DB.vehicles.get(id, {})
	if st == &"swim" and String(def.get("class", "")) != "capsule":
		return "TOAST_VEHICLE_NO_WATER"
	if active and is_instance_valid(active) and active.id == id and active.disabled_for > 0.0:
		return "TOAST_VEHICLE_REPAIRING"
	return ""


func summon(p: Player) -> bool:
	var why := summon_block_reason(p)
	if why != "":
		EventBus.toast.emit(tr(why))
		return false
	var id := PlayerData.vehicle_equipped
	var def: Dictionary = DB.vehicles[id]
	var amphibious := String(def.get("class", "")) == "capsule"
	var spot: Variant = find_spot(p, def, amphibious)
	if spot == null:
		EventBus.toast.emit(tr("TOAST_VEHICLE_NO_ROOM"))
		return false
	var keep_hull := -1.0
	if active and is_instance_valid(active):
		if active.id == id:
			keep_hull = active.hull
		put_away()
	var v := Vehicle.new()
	v.name = "Vehicle_" + String(id)
	v.setup(id)
	v.heading = p.facing_yaw
	add_child(v)
	if keep_hull >= 0.0:
		v.hull = keep_hull
	v.global_position = spot
	var entry := VehicleEntry.new()
	entry.vehicle = v
	v.add_child(entry)
	active = v
	_arrive(v)
	return true


## Candidate spots around the player, first free one wins.
func find_spot(p: Player, def: Dictionary, amphibious: bool) -> Variant:
	var col: Dictionary = def.get("collider", {})
	var size := Vector3(float(col.get("radius", 0.5)) * 2.0 + 0.3, float(col.get("height", 1.2)), float(col.get("length", 2.0)) + 0.3)
	var basis := Basis(Vector3.UP, p.facing_yaw)
	var gw := Game.world as GameWorld
	var slope_limit := float(def.get("handling", {}).get("slope_limit", 0.6))
	for off: Vector3 in SPOT_OFFSETS:
		var c: Vector3 = p.global_position + basis * off
		var ground := gen.height(c.x, c.z)
		var wet := ground < WorldGen.SEA_LEVEL - 0.4
		if wet and not amphibious:
			continue
		if not wet and gen.normal(c.x, c.z).y < maxf(slope_limit, 0.8):
			continue
		if gw and gw.streamer and not gw.streamer.has_collision_at(c):
			continue
		c.y = WorldGen.SEA_LEVEL - 0.9 if wet else ground + 0.05
		if not spot_is_free(p.get_world_3d(), c + Vector3.UP * (size.y * 0.5 + 0.35), size, [p.get_rid()]):
			continue
		if _people_near(c, 2.2):
			continue
		return c
	return null


## True when a box at `center` touches no terrain feature, structure, prop,
## creature, NPC or other vehicle.
static func spot_is_free(world: World3D, center: Vector3, size: Vector3, exclude: Array = []) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = size
	q.shape = box
	q.transform = Transform3D(Basis(), center)
	q.collision_mask = 1 | (1 << 1) | (1 << 2) | (1 << 3)
	var ex: Array[RID] = []
	for r in exclude:
		ex.append(r)
	q.exclude = ex
	return world.direct_space_state.intersect_shape(q, 1).is_empty()


func _people_near(c: Vector3, r: float) -> bool:
	for g in [&"creatures", &"npcs"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and (n as Node3D).global_position.distance_to(c) < r:
				return true
	return false


## Arrival: a gust sweeps in and the machine settles from a short drop onto
## its suspension (no portal, no hologram — it comes with the wind).
func _arrive(v: Vehicle) -> void:
	var land := v.global_position
	v.global_position = land + Vector3.UP * 1.2
	v.visual.scale = Vector3.ONE * 0.6
	var t := v.create_tween()
	t.set_parallel(true)
	t.tween_property(v, "global_position", land, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(v.visual, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	ElementFX.burst(self, land + Vector3.UP * 0.8, &"wind", 3.0)
	Effects.dust(self, land, 1.6)
	Audio.play_at(&"vehicle_summon", land, -1.0)
	if Game.camera_rig:
		Game.camera_rig.add_trauma(0.12)


func put_away() -> void:
	if active == null or not is_instance_valid(active):
		active = null
		return
	if active.driver:
		active.driver.exit_vehicle(false)
	Effects.dust(self, active.global_position, 1.0)
	active.queue_free()
	active = null


# --- Restoration (Garage bench) -------------------------------------------------------------------
## {ok, quest_done, missing: [{id, have, need}], glimmer_short}
static func restore_status(id: StringName) -> Dictionary:
	var def: Dictionary = DB.vehicles.get(id, {})
	var acq: Dictionary = def.get("acquire", {})
	var out := {"ok": true, "quest_done": Quests.is_completed(StringName(acq.get("quest", ""))), "missing": [], "glimmer_short": 0}
	for it in acq.get("items", []):
		var have := PlayerData.inventory.count_of(StringName(it["id"]))
		var need := int(it.get("count", 1))
		if have < need:
			(out["missing"] as Array).append({"id": it["id"], "have": have, "need": need})
	var g := int(acq.get("glimmer", 0))
	if PlayerData.glimmer < g:
		out["glimmer_short"] = g - PlayerData.glimmer
	out["ok"] = (out["missing"] as Array).is_empty() and int(out["glimmer_short"]) == 0 and not PlayerData.owns_vehicle(id)
	return out


## Pays and restores. Parts and schematics are consumed with the materials.
static func restore(id: StringName) -> bool:
	if not restore_status(id)["ok"]:
		return false
	var acq: Dictionary = DB.vehicles[id].get("acquire", {})
	for it in acq.get("items", []):
		PlayerData.inventory.remove(StringName(it["id"]), int(it.get("count", 1)))
	PlayerData.glimmer -= int(acq.get("glimmer", 0))
	PlayerData.own_vehicle(id, "earned")
	PlayerData.equip_vehicle(id)
	return true
