class_name BoardPanel
extends OverlayPanel
## Bounty board: today's offers (Quests.board_offers: daily rotation,
## avoiding the kinds of bounty just done) with their rewards and a
## "Take it" button; bounties already taken show their progress.

var board_id := ""


func open_board(id: String) -> void:
	board_id = id
	open_panel(tr("BOARD_TITLE"))


func refresh() -> void:
	clear_body()
	_purse.text = "%s ◆ %d" % [tr("SHOP_PURSE") % PlayerData.glimmer, PlayerData.jade]
	body.add_child(UITheme.label(tr("BOARD_HINT"), 19, UITheme.TEXT_DIM))
	var any := false
	for id in Quests.order:
		var q: Dictionary = Quests.defs[id]
		if q.get("type", "") == "bounty" and String(q.get("board", "")) == board_id and Quests.is_active(id):
			any = true
			var lines := PackedStringArray()
			for o in Quests.objective_lines(id):
				lines.append(("◇ " if o["done"] else "◆ ") + String(o["text"]) + ("  %d/%d" % [o["count"], o["need"]] if int(o["need"]) > 1 else ""))
			body.add_child(card(tr(q.get("title_key", "")), "\n".join(lines), tr("BOARD_TAKEN"), false, func() -> void: pass))
	for id in Quests.board_offers(board_id, 3):
		any = true
		var q: Dictionary = Quests.defs[id]
		var text := tr(q.get("desc_key", "")) + "\n" + tr("JOURNAL_REWARDS") + "  " + " · ".join(Rewards.describe(q.get("rewards", {})))
		body.add_child(card(tr(q.get("title_key", "")), text, tr("BOARD_ACCEPT"), true, func() -> void:
			if Quests.start(id):
				Quests.set_tracked(id)
				Audio.play_ui(&"quest_start", -3.0)
			refresh()))
	if not any:
		body.add_child(UITheme.label(tr("BOARD_EMPTY"), 21, UITheme.TEXT))
