class_name AltarPanel
extends OverlayPanel
## Warden altar: spend Jade on lasting upgrades (data/upgrades.json) and
## wear the trail cosmetics you have found (data/cosmetics.json). Cosmetics
## only colour effects (weapon trail, glider ribbons, dash echoes).

const SLOTS := ["trail", "glider_trail", "afterimage"]


func refresh() -> void:
	clear_body()
	_purse.text = "◆ %d  %s" % [PlayerData.jade, tr("JADE")]
	body.add_child(UITheme.title(tr("ALTAR_UPGRADES"), 26, UITheme.ACCENT_2))
	for uid in DB.upgrades:
		var u: Dictionary = DB.upgrades[uid]
		var lvl := PlayerData.upgrade_level(uid)
		var max_lvl := (u.get("costs", []) as Array).size()
		var cost := PlayerData.upgrade_cost(uid)
		var pips := ""
		for i in max_lvl:
			pips += "◆" if i < lvl else "◇"
		var text := "%s   %s" % [tr(u.get("desc_key", "")), pips]
		var action := tr("ALTAR_MAXED") if cost < 0 else tr("ALTAR_OFFER") % cost
		body.add_child(card(tr(u.get("name_key", "")), text, action, cost >= 0 and PlayerData.jade >= cost, func() -> void:
			if PlayerData.buy_upgrade(uid):
				Audio.play_ui(&"jade", -2.0)
				EventBus.toast.emit(tr("ALTAR_BLESSED") % tr(u.get("name_key", "")))
			refresh()))
	body.add_child(UITheme.title(tr("ALTAR_COSMETICS"), 26, UITheme.ACCENT_2))
	var owned_any := false
	for slot in SLOTS:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 10)
		var owned: Array = []
		for cid in DB.cosmetics:
			var c: Dictionary = DB.cosmetics[cid]
			if String(c.get("slot", "")) == slot and PlayerData.cosmetics.has(String(cid)):
				owned.append(cid)
		if owned.is_empty():
			continue
		owned_any = true
		body.add_child(UITheme.label(tr("COS_SLOT_" + slot.to_upper()), 20, UITheme.TEXT_DIM))
		body.add_child(row)
		var current := String(PlayerData.cosmetic_slots.get(slot, ""))
		var none := UITheme.button(tr("COS_DEFAULT"), 54)
		none.toggle_mode = true
		none.button_pressed = current == ""
		none.pressed.connect(func() -> void:
			PlayerData.use_cosmetic(slot, "")
			refresh())
		row.add_child(none)
		for cid in owned:
			var c: Dictionary = DB.cosmetics[cid]
			var b := UITheme.button(tr(c.get("name_key", "")), 54)
			b.toggle_mode = true
			b.button_pressed = current == String(cid)
			b.add_theme_color_override("font_color", Color.from_string(String(c.get("color", "#ffffff")), Color.WHITE))
			b.pressed.connect(func() -> void:
				PlayerData.use_cosmetic(slot, String(cid))
				refresh())
			row.add_child(b)
	if not owned_any:
		body.add_child(UITheme.label(tr("ALTAR_NO_COSMETICS"), 19, UITheme.TEXT_DIM))
