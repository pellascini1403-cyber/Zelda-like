class_name WardenAltar
extends Interactable
## Warden altar: where Jade — earned only by exploring, challenges, bosses
## and quests — becomes lasting upgrades (glide, breath, heart, winds,
## edge) and cosmetic trails. Found at shrines and camps across the island.

static var _mesh: Mesh


func _ready() -> void:
	radius = 1.8
	super._ready()
	add_to_group(&"warden_altars")
	if _mesh == null:
		_mesh = QuestObject.mesh_for("altar")
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = WorldMaterials.get_mat(&"architecture")
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.0, 1.3)
	cs.shape = box
	cs.position.y = 0.5
	body.add_child(cs)
	add_child(body)


func prompt_key() -> String:
	return "PROMPT_ALTAR"


func interact(player: Player) -> void:
	player.start_busy(&"interact", 0.3)
	ElementFX.ring(self, global_position + Vector3.UP * 1.0, &"jade", 1.6, 0.4)
	Audio.play_at(&"jade", global_position, -3.0)
	EventBus.panel_requested.emit(&"altar", "")
