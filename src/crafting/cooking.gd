class_name Cooking
extends RefCounted
## Experimental cooking. Every ingredient contributes effect tags
## (ItemData.cook, e.g. {"heal": 2, "warm": 1}). The pot resolves:
##   1. exact special recipes (data/cooking.json "specials")
##   2. otherwise the dominant effect tag decides the dish; a second effect of
##      similar strength spoils the pot ("conflict") -> Murky Stew
##   3. potency = sum of the dominant tag, heal adds bonus healing
## Discovered combinations are written to the cookbook.

const MAX_INGREDIENTS := 5


static func is_ingredient(it: ItemData) -> bool:
	return it != null and not it.cook.is_empty()


static func combo_key(ids: Array) -> String:
	var s: Array = ids.map(func(x: Variant) -> String: return String(x))
	s.sort()
	return ",".join(s)


## Pure function: predicts the result without touching the inventory.
## Returns { "item": StringName, "potency": float, "heal_bonus": float }
static func resolve(ids: Array) -> Dictionary:
	var rules: Dictionary = DB.cooking
	var key := combo_key(ids)
	for sp in rules.get("specials", []):
		if combo_key(sp["ingredients"]) == key:
			return {"item": StringName(sp["item"]), "potency": float(sp.get("potency", 2.0)), "heal_bonus": 0.0}
	var tags := {}
	var heal := 0.0
	var inedible := 0
	for id in ids:
		var it := DB.item(StringName(id))
		if not is_ingredient(it):
			inedible += 1
			continue
		for t in it.cook:
			if t == "heal":
				heal += float(it.cook[t])
			else:
				tags[t] = tags.get(t, 0.0) + float(it.cook[t])
	if inedible > 0 and inedible >= ids.size() - inedible:
		return {"item": StringName(rules.get("failure_item", "murky_stew")), "potency": 1.0, "heal_bonus": 0.0}
	var dishes: Dictionary = rules.get("dish_for_tag", {})
	if tags.is_empty():
		if heal <= 0.0:
			return {"item": StringName(rules.get("failure_item", "murky_stew")), "potency": 1.0, "heal_bonus": 0.0}
		return {"item": StringName(dishes.get("heal", "hearty_stew")), "potency": 1.0 + heal * 0.35, "heal_bonus": 0.0}
	var sorted := tags.keys()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool: return tags[a] > tags[b])
	var top: String = sorted[0]
	if sorted.size() > 1 and tags[sorted[1]] >= tags[top] * float(rules.get("conflict_ratio", 0.75)):
		return {"item": StringName(rules.get("failure_item", "murky_stew")), "potency": 1.0, "heal_bonus": heal * 4.0}
	var potency := minf(float(tags[top]), float(rules.get("max_potency", 3.0)))
	return {"item": StringName(dishes.get(top, "hearty_stew")), "potency": potency, "heal_bonus": heal * 6.0}


## Consumes ingredients, produces the dish, records it in the cookbook.
static func cook(ids: Array) -> Dictionary:
	if ids.is_empty():
		return {}
	var res := resolve(ids)
	for id in ids:
		if not PlayerData.inventory.remove(StringName(id), 1):
			return {}
	var data := {"potency": snappedf(res["potency"], 0.1)}
	if res["heal_bonus"] > 0.0:
		data["heal_bonus"] = res["heal_bonus"]
	PlayerData.inventory.add(res["item"], 1, data)
	var key := combo_key(ids)
	var is_new := not PlayerData.cookbook.has(key)
	PlayerData.cookbook[key] = String(res["item"])
	if is_new:
		EventBus.recipe_discovered.emit(res["item"])
	EventBus.item_acquired.emit(res["item"], 1)
	EventBus.dish_cooked.emit(res["item"])
	Audio.play_ui(&"cook")
	return res


static func known_result(ids: Array) -> String:
	return PlayerData.cookbook.get(combo_key(ids), "")
