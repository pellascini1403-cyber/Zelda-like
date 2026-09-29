class_name Chest
extends Interactable
## Treasure chest. Contents come from a loot table (or a fixed reward for
## hand-placed labyrinth chests). Opened state persists forever.

var chest_id := ""
var loot_table: StringName = &"chest_common"
var fixed_items: Array = []
var grand := false
var _lid: Node3D
var _opened := false


static func create(id: String, table: StringName, items: Array = [], is_grand: bool = false) -> Chest:
	var c := Chest.new()
	c.chest_id = id
	c.loot_table = table
	c.fixed_items = items
	c.grand = is_grand
	c.radius = 1.3
	return c


func _ready() -> void:
	add_to_group(&"chests")
	super._ready()
	_opened = WorldState.opened.has(chest_id)
	var s := 1.35 if grand else 1.0
	var wood := Color(0.5, 0.33, 0.2)
	var trim := Color(0.85, 0.7, 0.35) if grand else Color(0.45, 0.45, 0.48)
	var b := MeshKit.Builder.new()
	b.box(Vector3(0, 0.3, 0) * s, Vector3(1.1, 0.6, 0.7) * s, wood)
	b.box(Vector3(0, 0.3, 0.36) * s, Vector3(1.14, 0.1, 0.02) * s, trim)
	b.box(Vector3(0, 0.3, -0.36) * s, Vector3(1.14, 0.1, 0.02) * s, trim)
	var base := MeshInstance3D.new()
	base.mesh = b.commit()
	base.material_override = WorldMaterials.get_mat(&"vertex_color")
	add_child(base)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.6, 0.35) * s
	add_child(_lid)
	var lb := MeshKit.Builder.new()
	lb.box(Vector3(0, 0.1, -0.35) * s, Vector3(1.12, 0.2, 0.72) * s, wood * 1.1)
	lb.box(Vector3(0, 0.1, -0.7) * s, Vector3(0.16, 0.16, 0.04) * s, trim)
	var lid := MeshInstance3D.new()
	lid.mesh = lb.commit()
	lid.material_override = WorldMaterials.get_mat(&"vertex_color")
	_lid.add_child(lid)
	var col := StaticBody3D.new()
	col.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.8, 0.7) * s
	cs.shape = box
	cs.position.y = 0.4 * s
	col.add_child(cs)
	add_child(col)
	if _opened:
		_lid.rotation.x = -1.9
	elif grand:
		# A faint glow so treasure reads from across a room.
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.85, 0.5)
		l.light_energy = 0.8
		l.omni_range = 4.0
		l.position.y = 1.2
		add_child(l)


func prompt_key() -> String:
	return "PROMPT_OPEN"


func can_interact() -> bool:
	return not _opened


func interact(player: Player) -> void:
	_opened = true
	WorldState.opened[chest_id] = true
	player.start_busy(&"interact", 0.6)
	player.visual.play_action(&"interact", 0.6)
	create_tween().tween_property(_lid, "rotation:x", -1.9, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var items: Array = []
	if fixed_items.is_empty():
		items = DB.roll_loot(loot_table)
	else:
		for f in fixed_items:
			items.append({"id": StringName(f["id"]), "count": int(f.get("count", 1))})
	for it in items:
		var added := PlayerData.inventory.add(it["id"], it["count"])
		if added > 0:
			EventBus.item_acquired.emit(it["id"], added)
		elif added < it["count"]:
			Pickup.spawn(get_parent(), global_position + Vector3.UP, it["id"], it["count"] - added)
	Audio.play_at(&"chest_open", global_position, 0.0)
	if grand:
		Audio.play_ui(&"discovery", 0.0)
	Effects.sparks(self, global_position + Vector3.UP * 0.8, Color(1.0, 0.9, 0.5), 1.0)
	EventBus.chest_opened.emit(chest_id, items)
	for c in get_children():
		if c is OmniLight3D:
			c.queue_free()
