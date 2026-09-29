class_name ItemData
extends Resource
## Definition of every item: weapons, armor, materials, food, tools, key items.
## Category-specific blocks (weapon/armor/effects) are optional.

const CATEGORIES: Array[StringName] = [&"weapon", &"armor", &"material", &"food", &"tool", &"key"]

@export var id: StringName
@export var category: StringName = &"material"
@export var name_key: String
@export var desc_key: String
@export var icon: String = ""
## Optional in-world / in-hand model. Empty = placeholder.
@export var model: String = ""
@export var max_stack: int = 99
@export var value: int = 1
@export var tags: PackedStringArray = []
@export var rarity: int = 0

# --- Weapon --------------------------------------------------------------
@export var weapon: Dictionary = {}
# --- Armor ---------------------------------------------------------------
@export var armor: Dictionary = {}
# --- Consumable effects ----------------------------------------------------
## Array of { "type": "heal"|"stamina"|"buff", "amount": float, "buff": id, "duration": s }
@export var effects: Array = []
## What the item does when used from the quick slot: eat | throw | repair | none
@export var use_action: StringName = &"none"
## Cooking contribution: effect tag -> potency. See data/cooking.json.
@export var cook: Dictionary = {}


static func from_dict(d: Dictionary) -> ItemData:
	var it := ItemData.new()
	it.id = StringName(d.get("id", ""))
	it.category = StringName(d.get("category", "material"))
	it.name_key = d.get("name_key", "ITEM_" + String(it.id).to_upper())
	it.desc_key = d.get("desc_key", it.name_key + "_DESC")
	it.icon = d.get("icon", "")
	it.model = d.get("model", "")
	var default_stack := 1 if it.category in [&"weapon", &"armor", &"key"] else 99
	it.max_stack = d.get("max_stack", default_stack)
	it.value = d.get("value", 1)
	it.tags = PackedStringArray(d.get("tags", []))
	it.rarity = d.get("rarity", 0)
	it.weapon = d.get("weapon", {})
	it.armor = d.get("armor", {})
	it.effects = d.get("effects", [])
	it.use_action = StringName(d.get("use_action", "none"))
	it.cook = d.get("cook", {})
	return it


func is_stackable() -> bool:
	return max_stack > 1


func is_weapon() -> bool:
	return category == &"weapon"


func has_tag(tag: String) -> bool:
	return tags.has(tag)


# --- Weapon helpers (defaults keep content JSON small) ----------------------
func w(key: String, default_value: Variant) -> Variant:
	return weapon.get(key, default_value)
