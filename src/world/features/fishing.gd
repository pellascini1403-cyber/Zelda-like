class_name Fishing
extends RefCounted
## Species tables for FishingSpot (data/fishing.json):
##   {"waters": {"lake": [{"item", "weight", "period", "hours", "weather", "rare"}...], ...}}
## Rare fish come only under their conditions (a moon carp at night, a
## storm eel in storms). Catching a species a discovery asks for
## ("trigger": "catch", "catch": item) finds it.


static func table(waters: String) -> Array:
	var out: Array = []
	for e: Dictionary in DB.fishing.get("waters", {}).get(waters, []):
		if SpawnDirector.entry_ok(e):
			out.append(e)
	return out


static func roll(waters: String, r: float) -> StringName:
	var opts := table(waters)
	var total := 0.0
	for e: Dictionary in opts:
		total += float(e.get("weight", 1.0))
	var pick := r * total
	for e: Dictionary in opts:
		pick -= float(e.get("weight", 1.0))
		if pick <= 0.0:
			return StringName(e["item"])
	return StringName(opts[0]["item"]) if not opts.is_empty() else &""


static func land(fish: StringName) -> void:
	var added := PlayerData.inventory.add(fish, 1)
	if added > 0:
		EventBus.item_acquired.emit(fish, added)
	Audio.play_ui(&"pickup", -4.0)
	var it := DB.item(fish)
	EventBus.toast.emit(TranslationServer.translate("FISH_CAUGHT") % (TranslationServer.translate(it.name_key) if it else String(fish)))
	WorldState.flags["fish:" + String(fish)] = true
	EventBus.fish_caught.emit(fish)
	for id: StringName in DB.discovery_order:
		var d: Dictionary = DB.discoveries[id]
		if String(d.get("trigger", "")) == "catch" and String(d.get("catch", "")) == String(fish):
			DiscoveryDirector.discover(id)
