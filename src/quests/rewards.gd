class_name Rewards
extends RefCounted
## Single entry point for every reward in the game (quests, bounties,
## discoveries, bosses, events, challenges).
##
## Duplicate guard: each grant has a `source` id ("quest:<id>:<n>",
## "event:<id>:<day>", ...). A source is recorded in WorldState before
## anything is given, so a reward can never be paid twice — not by a
## re-entrant signal, a reload, or a quest re-completing after a data edit.
##
## Reward dictionary (all keys optional):
##   items: [{id, count}]      glimmer: int       jade: int
##   ability: id               flags: [..] / flag  cosmetic: id
##   max_stamina / max_health  recipes: [[ingredient ids...], ...]
##   reveal: {pos: [x, z], radius: cells} (or a list)  heal: true


static func granted(source: String) -> bool:
	return WorldState.flags.has("rw:" + source)


## Returns false (and gives nothing) if this source already paid out.
static func grant(r: Dictionary, source: String) -> bool:
	if r.is_empty() or granted(source):
		return false
	WorldState.flags["rw:" + source] = true
	for it in r.get("items", []):
		var n := int(it.get("count", 1))
		var added := PlayerData.inventory.add(StringName(it["id"]), n)
		if added > 0:
			EventBus.item_acquired.emit(StringName(it["id"]), added)
	if r.has("glimmer"):
		PlayerData.glimmer += int(r["glimmer"])
	if r.has("jade"):
		PlayerData.add_jade(int(r["jade"]))
	if r.has("ability"):
		PlayerData.unlock_ability(StringName(r["ability"]))
	var flags: Array = r.get("flags", [])
	if r.has("flag"):
		flags = flags + [r["flag"]]
	for f in flags:
		Quests.set_flag(StringName(f))
	if r.has("max_stamina"):
		PlayerData.max_stamina += float(r["max_stamina"])
		PlayerData.restore_stamina(float(r["max_stamina"]))
	if r.has("max_health"):
		PlayerData.max_health += float(r["max_health"])
		PlayerData.heal(PlayerData.max_health, true)
	if r.get("heal", false):
		PlayerData.heal(PlayerData.max_health, true)
	for combo in r.get("recipes", []):
		var res := Cooking.resolve(combo)
		if not res.is_empty():
			PlayerData.cookbook[Cooking.combo_key(combo)] = String(res["item"])
			EventBus.recipe_discovered.emit(res["item"])
	if r.has("cosmetic"):
		PlayerData.own_cosmetic(StringName(r["cosmetic"]))
	if r.has("reveal"):
		var reveals: Array = r["reveal"] if r["reveal"] is Array else [r["reveal"]]
		for rv: Dictionary in reveals:
			var p: Array = rv.get("pos", [0, 0])
			WorldState.explore(Vector3(p[0], 0, p[1]), int(rv.get("radius", 6)))
	EventBus.rewards_granted.emit(source, r)
	return true


## One line per reward for popups / the journal ("Wayfarer Edge ×1", "◆ 3 Jade").
static func describe(r: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for it in r.get("items", []):
		var d := DB.item(StringName(it["id"]))
		if d:
			out.append("%s ×%d" % [TranslationServer.translate(d.name_key), int(it.get("count", 1))])
	if r.has("glimmer"):
		out.append(TranslationServer.translate("REWARD_GLIMMER") % int(r["glimmer"]))
	if r.has("jade"):
		out.append(TranslationServer.translate("REWARD_JADE") % int(r["jade"]))
	if r.has("ability"):
		out.append(TranslationServer.translate(DB.abilities.get(StringName(r["ability"]), {}).get("name_key", "")))
	if r.has("max_stamina"):
		out.append(TranslationServer.translate("REWARD_STAMINA"))
	if r.has("max_health"):
		out.append(TranslationServer.translate("REWARD_HEALTH"))
	if not (r.get("recipes", []) as Array).is_empty():
		out.append(TranslationServer.translate("REWARD_RECIPE"))
	if r.has("cosmetic"):
		out.append(TranslationServer.translate(DB.cosmetics.get(StringName(r["cosmetic"]), {}).get("name_key", "")))
	if r.has("reveal"):
		out.append(TranslationServer.translate("REWARD_MAP"))
	return out
