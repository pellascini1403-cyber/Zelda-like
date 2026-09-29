class_name ItemStack
extends RefCounted
## A stack of identical items. `data` holds per-instance state (weapon
## durability, dish potency...). Stacks only merge when their data is equal.

var id: StringName
var count: int = 1
var data: Dictionary = {}


func _init(item_id: StringName = &"", n: int = 1, d: Dictionary = {}) -> void:
	id = item_id
	count = n
	data = d.duplicate(true)


func def() -> ItemData:
	return DB.item(id)


func can_merge(item_id: StringName, d: Dictionary) -> bool:
	var it := def()
	return item_id == id and it != null and it.is_stackable() and count < it.max_stack and data.hash() == d.hash()


# --- Weapons -------------------------------------------------------------------
func durability() -> float:
	return data.get("durability", 0.0)


func max_durability() -> float:
	var it := def()
	return float(it.w("durability", 1)) if it else 1.0


func durability_ratio() -> float:
	return clampf(durability() / maxf(max_durability(), 1.0), 0.0, 1.0)


func is_heirloom() -> bool:
	var it := def()
	return it != null and bool(it.w("heirloom", false))


func is_blunted() -> bool:
	return is_heirloom() and durability() <= 0.0


func to_dict() -> Dictionary:
	return {"id": String(id), "count": count, "data": data}


static func from_dict(d: Dictionary) -> ItemStack:
	return ItemStack.new(StringName(d.get("id", "")), int(d.get("count", 1)), d.get("data", {}))


## Fresh instance data for a newly created item.
static func initial_data(item_id: StringName) -> Dictionary:
	var it := DB.item(item_id)
	if it and it.is_weapon():
		return {"durability": float(it.w("durability", 20))}
	return {}
