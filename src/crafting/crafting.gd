class_name Crafting
extends RefCounted
## Recipe crafting (data/crafting.json). Recipes may require a station
## ("campfire"): the player must be within reach of one.

const STATION_RANGE := 6.0


static func recipes() -> Array:
	return DB.crafting.values()


static func near_station(station: String) -> bool:
	if station == "":
		return true
	if Game.player == null:
		return false
	for n in Game.player.get_tree().get_nodes_in_group(StringName(station)):
		if (n as Node3D).global_position.distance_to(Game.player.global_position) < STATION_RANGE:
			return true
	return false


## Ingredient list as { item_id: count }.
static func requirements(recipe: Dictionary) -> Dictionary:
	var req := {}
	for ing in recipe["ingredients"]:
		req[StringName(ing)] = req.get(StringName(ing), 0) + 1
	return req


static func can_craft(recipe: Dictionary) -> bool:
	if not near_station(recipe.get("station", "")):
		return false
	var req := requirements(recipe)
	for id in req:
		if not PlayerData.inventory.has(id, req[id]):
			return false
	return PlayerData.inventory.can_add(StringName(recipe["result"]))


static func craft(recipe: Dictionary) -> bool:
	if not can_craft(recipe):
		return false
	var req := requirements(recipe)
	for id in req:
		PlayerData.inventory.remove(id, req[id])
	var result := StringName(recipe["result"])
	var n := int(recipe.get("count", 1))
	PlayerData.inventory.add(result, n)
	EventBus.item_acquired.emit(result, n)
	Audio.play_ui(&"craft")
	return true
