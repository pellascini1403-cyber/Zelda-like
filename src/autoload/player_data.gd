extends Node
## Persistent player progression: vitals, inventory, equipment, buffs,
## discovered recipes, abilities. Survives scene changes; saved as a whole.
##
## The Player node (src/player) is the *body*; this is the *character sheet*.

const EQUIP_SLOTS: Array[StringName] = [&"weapon", &"head", &"body", &"legs", &"accessory"]
const BASE_HEALTH := 100.0
const BASE_STAMINA := 100.0

var inventory := Inventory.new()
## slot -> ItemStack (weapons/armor are unique instances inside inventory)
var equipped: Dictionary = {}
var quick_item: StringName = &""

var max_health := BASE_HEALTH
var health := BASE_HEALTH
var max_stamina := BASE_STAMINA
var stamina := BASE_STAMINA
## buff id -> { "potency": float, "remaining": seconds }
var buffs: Dictionary = {}
## Cooking combos the player has discovered: key -> dish id
var cookbook: Dictionary = {}
var abilities: Dictionary = {}
var glimmer := 0
## Jade: the rare currency earned only by exploring, challenges and bosses
## (never sold). Spent at Warden altars on upgrades and cosmetics.
var jade := 0
## upgrade id -> level (data/upgrades.json)
var upgrades: Dictionary = {}
## Owned cosmetic ids and the ones in use per slot (trail, ribbon...).
var cosmetics: Dictionary = {}
var cosmetic_slots: Dictionary = {}


func _ready() -> void:
	inventory.changed.connect(func() -> void: EventBus.inventory_changed.emit())


func reset_new_game() -> void:
	inventory = Inventory.new()
	inventory.changed.connect(func() -> void: EventBus.inventory_changed.emit())
	equipped.clear()
	buffs.clear()
	cookbook.clear()
	abilities.clear()
	max_health = BASE_HEALTH
	health = BASE_HEALTH
	max_stamina = BASE_STAMINA
	stamina = BASE_STAMINA
	glimmer = 0
	jade = 0
	upgrades.clear()
	cosmetics.clear()
	cosmetic_slots.clear()
	for entry in DB.world.get("starting_items", []):
		inventory.add(StringName(entry["id"]), int(entry.get("count", 1)))
	var club := inventory.find_first(&"bough_club")
	if club:
		equip(club)
	for slot_item in [&"traveler_hood", &"traveler_coat", &"traveler_boots"]:
		var s := inventory.find_first(slot_item)
		if s:
			equip(s)
	quick_item = &"sunpear"


func _process(delta: float) -> void:
	if not Game.is_playing():
		return
	var expired: Array = []
	for id in buffs:
		buffs[id]["remaining"] -= delta
		if buffs[id]["remaining"] <= 0.0:
			expired.append(id)
	for id in expired:
		buffs.erase(id)
	if buffs.has(&"regen"):
		heal(buffs[&"regen"]["potency"] * 1.5 * delta, true)


# --- Vitals ---------------------------------------------------------------------------
func add_jade(n: int) -> void:
	jade = maxi(jade + n, 0)
	EventBus.jade_changed.emit(jade)


func upgrade_level(id: StringName) -> int:
	return int(upgrades.get(String(id), 0))


## Sum of an upgrade effect over its bought levels (data/upgrades.json).
func upgrade_bonus(id: StringName) -> float:
	var d: Dictionary = DB.upgrades.get(id, {})
	var lvl := upgrade_level(id)
	var per: Array = d.get("per_level", [])
	var total := 0.0
	for i in mini(lvl, per.size()):
		total += float(per[i])
	return total


func own_cosmetic(id: StringName) -> void:
	if cosmetics.has(String(id)):
		return
	cosmetics[String(id)] = true
	var c: Dictionary = DB.cosmetics.get(id, {})
	var slot := String(c.get("slot", "trail"))
	if not cosmetic_slots.has(slot):
		cosmetic_slots[slot] = String(id)


## Active cosmetic definition for a slot, or {} for the default look.
func cosmetic_in(slot: String) -> Dictionary:
	var id := StringName(cosmetic_slots.get(slot, ""))
	return DB.cosmetics.get(id, {})


## Colour of the cosmetic in `slot` (trail, glider_trail, afterimage).
## Cosmetics are effects only: the character model is never recoloured.
func cosmetic_color(slot: String, fallback: Color) -> Color:
	var c := cosmetic_in(slot)
	return Color.from_string(String(c.get("color", "")), fallback) if not c.is_empty() else fallback


## Wear an owned cosmetic ("" = default look).
func use_cosmetic(slot: String, id: String) -> void:
	if id == "":
		cosmetic_slots.erase(slot)
	elif cosmetics.has(id):
		cosmetic_slots[slot] = id


## Jade cost of the next level, or -1 when maxed.
func upgrade_cost(id: StringName) -> int:
	var costs: Array = DB.upgrades.get(id, {}).get("costs", [])
	var lvl := upgrade_level(id)
	return int(costs[lvl]) if lvl < costs.size() else -1


func buy_upgrade(id: StringName) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or jade < cost:
		return false
	add_jade(-cost)
	var lvl := upgrade_level(id)
	upgrades[String(id)] = lvl + 1
	var d: Dictionary = DB.upgrades.get(id, {})
	var gain := float((d.get("per_level", []) as Array)[lvl])
	match String(d.get("effect", "")):
		"max_stamina":
			max_stamina += gain
			restore_stamina(gain)
		"max_health":
			max_health += gain
			heal(max_health, true)
	EventBus.quest_event.emit(&"upgrade_bought")
	return true


func has_ability(id: StringName) -> bool:
	return abilities.has(String(id))


func unlock_ability(id: StringName) -> void:
	if has_ability(id):
		return
	abilities[String(id)] = true
	EventBus.ability_unlocked.emit(id)


func heal(amount: float, silent: bool = false) -> void:
	var before := health
	health = minf(health + amount, max_health)
	if not silent and health > before:
		EventBus.player_healed.emit(health - before)


func restore_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, max_stamina)


# --- Equipment ---------------------------------------------------------------------
func equip(stack: ItemStack) -> void:
	var it := stack.def()
	if it == null:
		return
	var slot: StringName = &"weapon" if it.is_weapon() else StringName(it.armor.get("slot", ""))
	if not slot in EQUIP_SLOTS:
		return
	equipped[slot] = stack
	EventBus.equipment_changed.emit(slot)


func unequip(slot: StringName) -> void:
	equipped.erase(slot)
	EventBus.equipment_changed.emit(slot)


func is_equipped(stack: ItemStack) -> bool:
	return stack in equipped.values()


func weapon() -> ItemStack:
	var s: ItemStack = equipped.get(&"weapon")
	if s != null and not s in inventory.stacks:
		equipped.erase(&"weapon")
		return null
	return s


func cycle_weapon() -> void:
	var weapons := inventory.in_category(&"weapon")
	if weapons.is_empty():
		return
	var cur := weapon()
	var i := weapons.find(cur)
	equip(weapons[(i + 1) % weapons.size()])


## Called on every landed hit. Handles warning, break and heirloom blunting.
func wear_weapon(amount: float = 1.0) -> void:
	var s := weapon()
	if s == null:
		return
	var before := s.durability_ratio()
	amount *= 1.0 - upgrade_bonus(&"edge")
	s.data["durability"] = maxf(s.durability() - amount, 0.0)
	if before > 0.25 and s.durability_ratio() <= 0.25 and not s.is_heirloom():
		EventBus.weapon_durability_warning.emit(s.id)
	if s.durability() <= 0.0 and not s.is_heirloom():
		var id := s.id
		inventory.remove_stack(s)
		equipped.erase(&"weapon")
		EventBus.weapon_broken.emit(id)
		# Auto-equip the best remaining weapon so combat keeps flowing.
		var best: ItemStack = null
		for w in inventory.in_category(&"weapon"):
			if best == null or float(w.def().w("damage", 0)) > float(best.def().w("damage", 0)):
				best = w
		if best:
			equip(best)
		EventBus.equipment_changed.emit(&"weapon")


func repair_weapon(stack: ItemStack, ratio: float) -> void:
	if stack == null:
		return
	stack.data["durability"] = minf(stack.durability() + stack.max_durability() * ratio, stack.max_durability())
	EventBus.inventory_changed.emit()


# --- Derived stats -------------------------------------------------------------------
func defense() -> float:
	var d := 0.0
	for slot in [&"head", &"body", &"legs", &"accessory"]:
		var s: ItemStack = equipped.get(slot)
		if s and s.def():
			d += float(s.def().armor.get("defense", 0))
	d += buff_potency(&"defense_up") * 4.0
	return d


func armor_bonus(key: String) -> float:
	var total := 0.0
	var sets := {}
	for slot in [&"head", &"body", &"legs", &"accessory"]:
		var s: ItemStack = equipped.get(slot)
		if s and s.def():
			total += float(s.def().armor.get(key, 0.0))
			var set_id: String = s.def().armor.get("set", "")
			if set_id != "":
				sets[set_id] = sets.get(set_id, 0) + 1
	for set_id in sets:
		if sets[set_id] >= 3:
			var bonus: Dictionary = DB.world.get("armor_sets", {}).get(set_id, {})
			total += float(bonus.get(key, 0.0))
	return total


func attack_mult() -> float:
	return 1.0 + buff_potency(&"attack_up") * 0.12


func speed_mult() -> float:
	return 1.0 + buff_potency(&"speed_up") * 0.06 + armor_bonus("speed")


func stamina_regen_mult() -> float:
	return 1.0 + armor_bonus("stamina_regen") + buff_potency(&"stamina_regen") * 0.1


func climb_speed_mult() -> float:
	return 1.0 + armor_bonus("climb_speed")


func cold_resist() -> float:
	return armor_bonus("cold_resist") + buff_potency(&"cold_resist")


func heat_resist() -> float:
	return armor_bonus("heat_resist") + buff_potency(&"heat_resist")


func lightning_immune() -> bool:
	return armor_bonus("lightning_immune") > 0.0


func carries_metal() -> bool:
	for s: ItemStack in equipped.values():
		if s and s.def() and (s.def().has_tag("metal")):
			return true
	return false


func has_glider() -> bool:
	return inventory.has(&"vela_glider")


func glide_efficiency() -> float:
	var base := 0.6 if inventory.has(&"current_thread") else 1.0
	return base * (1.0 - upgrade_bonus(&"vela"))


func buff_potency(id: StringName) -> float:
	return float(buffs[id]["potency"]) if buffs.has(id) else 0.0


func apply_buff(id: StringName, potency: float, duration: float) -> void:
	if buffs.has(id) and buffs[id]["potency"] > potency:
		buffs[id]["remaining"] = maxf(buffs[id]["remaining"], duration)
		return
	buffs[id] = {"potency": potency, "remaining": duration}


# --- Consumables ------------------------------------------------------------------------
## Applies an item's effects. `scale` multiplies them (cooked dish potency).
func consume(stack: ItemStack) -> bool:
	var it := stack.def()
	if it == null or it.effects.is_empty():
		return false
	var potency: float = stack.data.get("potency", 1.0)
	if stack.data.has("heal_bonus"):
		heal(float(stack.data["heal_bonus"]))
	for eff in it.effects:
		match String(eff.get("type", "")):
			"heal":
				heal(float(eff.get("amount", 0)) * potency)
			"stamina":
				restore_stamina(float(eff.get("amount", 0)) * potency)
				if eff.has("overfill"):
					stamina = minf(stamina + float(eff["overfill"]) * potency, max_stamina * 1.5)
			"max_health":
				max_health += float(eff.get("amount", 20))
				health = max_health
				EventBus.toast.emit(tr("TOAST_MAX_HEALTH"))
			"max_stamina":
				max_stamina += float(eff.get("amount", 20))
				stamina = max_stamina
				EventBus.toast.emit(tr("TOAST_MAX_STAMINA"))
			"buff":
				apply_buff(StringName(eff["buff"]), float(eff.get("amount", 1.0)) * potency, float(eff.get("duration", 120.0)) * (0.6 + potency * 0.4))
	inventory.remove_stack(stack)
	Audio.play_ui(&"eat")
	return true


# --- Save -----------------------------------------------------------------------------------
func save_state() -> Dictionary:
	var eq := {}
	for slot in equipped:
		var idx := inventory.stacks.find(equipped[slot])
		if idx >= 0:
			eq[String(slot)] = idx
	var bf := {}
	for id in buffs:
		bf[String(id)] = buffs[id]
	return {
		"inventory": inventory.to_array(), "equipped": eq, "quick_item": String(quick_item),
		"health": health, "max_health": max_health, "stamina": stamina, "max_stamina": max_stamina,
		"buffs": bf, "cookbook": cookbook, "abilities": abilities, "glimmer": glimmer,
		"jade": jade, "upgrades": upgrades, "cosmetics": cosmetics, "cosmetic_slots": cosmetic_slots,
	}


func load_state(d: Dictionary) -> void:
	inventory.from_array(d.get("inventory", []))
	equipped.clear()
	var eq: Dictionary = d.get("equipped", {})
	for slot in eq:
		var idx := int(eq[slot])
		if idx >= 0 and idx < inventory.stacks.size():
			equipped[StringName(slot)] = inventory.stacks[idx]
	quick_item = StringName(d.get("quick_item", ""))
	max_health = d.get("max_health", BASE_HEALTH)
	health = clampf(d.get("health", max_health), 1.0, max_health)
	max_stamina = d.get("max_stamina", BASE_STAMINA)
	stamina = d.get("stamina", max_stamina)
	buffs.clear()
	var bf: Dictionary = d.get("buffs", {})
	for id in bf:
		buffs[StringName(id)] = bf[id]
	cookbook = d.get("cookbook", {})
	abilities = d.get("abilities", {})
	glimmer = d.get("glimmer", 0)
	jade = int(d.get("jade", 0))
	upgrades = d.get("upgrades", {})
	cosmetics = d.get("cosmetics", {})
	cosmetic_slots = d.get("cosmetic_slots", {})
	for slot in EQUIP_SLOTS:
		EventBus.equipment_changed.emit(slot)
