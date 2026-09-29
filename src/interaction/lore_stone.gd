class_name LoreStone
extends Interactable
## Environmental storytelling: carved tablets, murals, journals. Text lives in
## the localization tables (lore_key).

var lore_key := ""
var title_key := ""


func _ready() -> void:
	radius = 1.4
	super._ready()
	var b := MeshKit.Builder.new()
	b.box(Vector3(0, 0.9, 0), Vector3(1.1, 1.8, 0.28), Color(0.5, 0.52, 0.5))
	b.box(Vector3(0, 1.2, 0.15), Vector3(0.7, 0.05, 0.02), Color(0.35, 0.8, 0.9))
	b.box(Vector3(0, 1.0, 0.15), Vector3(0.5, 0.05, 0.02), Color(0.35, 0.8, 0.9))
	b.box(Vector3(0, 0.8, 0.15), Vector3(0.6, 0.05, 0.02), Color(0.35, 0.8, 0.9))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.material_override = WorldMaterials.get_mat(&"vertex_color")
	add_child(mi)
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 1.8, 0.3)
	cs.shape = box
	cs.position.y = 0.9
	col.add_child(cs)
	add_child(col)


func prompt_key() -> String:
	return "PROMPT_READ"


func interact(_player: Player) -> void:
	EventBus.dialogue_requested.emit(title_key, PackedStringArray([lore_key]))
	var flag := "lore_" + lore_key
	if not WorldState.flags.has(flag):
		WorldState.flags[flag] = true
		Audio.play_ui(&"discovery", -2.0)
