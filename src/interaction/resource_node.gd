class_name ResourceNode
extends Interactable
## Gatherable resource placed by the spawn director (data/resource_nodes.json).
## mode "gather": context button, quick pick.
## mode "strike": must be hit with a weapon (hammers are best), yields more.
## Harvested state persists and respawns after in-game hours.

var def: Dictionary
var node_id := ""
var _body: StaticBody3D
var _hits_left := 3
var _visual: Node3D


static func create(definition: Dictionary, id: String) -> ResourceNode:
	var r := ResourceNode.new()
	r.def = definition
	r.node_id = id
	r.radius = definition.get("radius", 0.9)
	return r


func _ready() -> void:
	add_to_group(&"resource_nodes")
	super._ready()
	_visual = ResourceVisuals.build(def)
	add_child(_visual)
	if def.get("mode", "gather") == "strike":
		_hits_left = int(def.get("hits", 3))
		var st := StrikeTarget.new()
		st.target = self
		_body = st
		_body.collision_layer = 1 << 3
		_body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = float(def.get("radius", 0.9))
		cs.shape = s
		cs.position.y = s.radius * 0.6
		_body.add_child(cs)
		add_child(_body)


func prompt_key() -> String:
	return "PROMPT_GATHER"


func can_interact() -> bool:
	return def.get("mode", "gather") == "gather"


func interact(player: Player) -> void:
	player.start_busy(&"gather", 0.45)
	player.visual.play_action(&"gather", 0.45)
	_harvest()


## Called by StrikeTarget when a weapon hits the node.
func on_struck(info: DamageInfo) -> void:
	var w := PlayerData.weapon()
	var power := 1
	if w and w.def() and String(w.def().w("type", "")) == "hammer":
		power = 3
	if info.kind == &"explosion" or info.kind == &"slam":
		power = 3
	_hits_left -= power
	Effects.hit_spark(self, global_position + Vector3.UP * 0.6, false)
	Audio.play_at(&"strike_rock", global_position, 0.0)
	_visual.scale = Vector3.ONE * 0.9
	create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.15)
	if _hits_left <= 0:
		_harvest()


func _harvest() -> void:
	var loot := DB.roll_loot(StringName(def.get("loot", "")))
	for drop in loot:
		if def.get("mode", "gather") == "strike":
			Pickup.spawn(get_parent(), global_position + Vector3(randf_range(-0.5, 0.5), 0.8, randf_range(-0.5, 0.5)), drop["id"], drop["count"])
		else:
			var added := PlayerData.inventory.add(drop["id"], drop["count"])
			if added > 0:
				EventBus.item_acquired.emit(drop["id"], added)
	Audio.play_at(&"gather", global_position, -3.0)
	Effects.leaves(self, global_position + Vector3.UP * 0.4)
	WorldState.mark_harvested(node_id, float(def.get("respawn_hours", 48)))
	queue_free()
