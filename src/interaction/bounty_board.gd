class_name BountyBoard
extends Interactable
## Notice board with the local bounties (repeatable quests of type
## "bounty" whose "board" matches). Offers rotate daily and avoid the
## categories the player has just done (Quests.board_offers).

var board_id := "hamlet"
static var _mesh: Mesh


func _ready() -> void:
	radius = 1.6
	super._ready()
	add_to_group(&"bounty_boards")
	var mi := MeshInstance3D.new()
	if _mesh == null:
		_mesh = QuestObject.mesh_for("board")
	mi.mesh = _mesh
	mi.material_override = WorldMaterials.get_mat(&"architecture")
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.3, 0.3)
	cs.shape = box
	cs.position.y = 1.15
	body.add_child(cs)
	add_child(body)


func prompt_key() -> String:
	return "PROMPT_BOARD"


func interact(player: Player) -> void:
	player.start_busy(&"interact", 0.3)
	EventBus.panel_requested.emit(&"board", board_id)
