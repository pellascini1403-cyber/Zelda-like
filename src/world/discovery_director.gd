class_name DiscoveryDirector
extends Node
## Discoveries: optional, one-off wonders that are not quests — a tree that
## only blooms at night, a bell that rings only in fog, an island that rises
## in storms, a ruin you can only reach gliding. Each lives in
## data/discoveries.json:
##
##   id, region, name_key, desc_key, hint_key (rumour, shown in the Atlas)
##   pos: [x, z] (or [x, y, z]) / poi: id + pos offset
##   radius: reach distance (m)        trigger: reach | interact
##   conditions: {period, hours: [a, b], weather: [...], not_weather,
##                flag, not_flag, ability, state: [player states],
##                vehicle: true|id, mount: true, min_y, max_y}
##   spawns: QuestSpawner entries shown while it is waiting to be found
##           (and after, when "persist": true)
##   reward: Rewards dictionary (paid once, source "disc:<id>")
##
## Found = WorldState flag "disc:<id>" (saved with the world, never paid twice).

const CHECK_EVERY := 0.4
const NEAR := 220.0

var _timer := 0.0


func _ready() -> void:
	add_to_group(&"discovery_director")


static func is_found(id: StringName) -> bool:
	return WorldState.flags.has("disc:" + String(id))


static func found_count(region: String = "") -> int:
	var n := 0
	for id: StringName in DB.discovery_order:
		if (region == "" or String(DB.discoveries[id].get("region", "")) == region) and is_found(id):
			n += 1
	return n


static func anchor(d: Dictionary) -> Variant:
	var base := Vector3.ZERO
	if d.has("poi"):
		var pp: Variant = Quests.poi_pos(String(d["poi"]))
		if pp == null:
			return null
		base = pp
	var p: Array = d.get("pos", [0, 0])
	return base + (Vector3(p[0], 0, p[1]) if p.size() == 2 else Vector3(p[0], p[1], p[2]))


## World-state conditions (time, weather, flags): what decides whether the
## discovery's things exist right now.
static func world_ok(c: Dictionary) -> bool:
	if c.has("period") and (String(c["period"]) == "night") != Clock.is_night():
		return false
	if c.has("hours"):
		var hr: Array = c["hours"]
		var h := Clock.hour
		var a := float(hr[0])
		var b := float(hr[1])
		if not ((h >= a and h < b) if a <= b else (h >= a or h < b)):
			return false
	var w := String(Weather.target)
	if c.has("weather") and not w in c["weather"]:
		return false
	if w in c.get("not_weather", []):
		return false
	if c.has("flag") and not WorldState.flags.has(String(c["flag"])):
		return false
	if c.has("not_flag") and WorldState.flags.has(String(c["not_flag"])):
		return false
	return true


## Player conditions (how you have to be there: gliding, diving, on the
## Bellhull, high enough...). Checked only at the moment of discovery.
static func player_ok(c: Dictionary, p: Player) -> bool:
	if p == null:
		return false
	if c.has("ability") and not PlayerData.has_ability(StringName(c["ability"])):
		return false
	if c.has("state") and not String(p.state_name()) in c["state"]:
		return false
	if c.has("vehicle"):
		if p.vehicle == null:
			return false
		if c["vehicle"] is String and String(p.vehicle.def.get("id", "")) != String(c["vehicle"]):
			return false
	if c.get("mount", false) and p.mount == null:
		return false
	if c.has("min_y") and p.global_position.y < float(c["min_y"]):
		return false
	if c.has("max_y") and p.global_position.y > float(c["max_y"]):
		return false
	return true


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or Game.player == null or not Game.is_playing():
		return
	_timer = CHECK_EVERY
	var p := Game.player as Player
	var pp := p.global_position
	for id: StringName in DB.discovery_order:
		if is_found(id):
			continue
		var d: Dictionary = DB.discoveries[id]
		if String(d.get("trigger", "reach")) != "reach":
			continue
		var at: Variant = anchor(d)
		if at == null:
			continue
		var a: Vector3 = at
		var flat := Vector2(pp.x - a.x, pp.z - a.z).length()
		if flat > NEAR or flat > float(d.get("radius", 6.0)):
			continue
		var c: Dictionary = d.get("conditions", {})
		if world_ok(c) and player_ok(c, p):
			discover(id)


## Marks a discovery found, pays it once, announces it.
static func discover(id: StringName) -> bool:
	var d: Dictionary = DB.discoveries.get(id, {})
	if d.is_empty() or is_found(id):
		return false
	WorldState.flags["disc:" + String(id)] = true
	var at: Variant = anchor(d)
	if at != null:
		WorldState.explore(at, 3)
	Rewards.grant(d.get("reward", {}), "disc:" + String(id))
	EventBus.title_card.emit(TranslationServer.translate(String(d.get("name_key", ""))), TranslationServer.translate("ATLAS_FOUND"))
	Audio.play_ui(&"discovery", -2.0)
	EventBus.discovery_made.emit(id)
	return true
