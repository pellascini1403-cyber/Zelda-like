class_name PuzzleGroup
extends Node3D
## Coordinates one puzzle: its elements (braziers, plates, anchors) report
## their state; when every element is active the puzzle is solved for good
## (WorldState flag "puzzle_<id>"), seals open and EventBus reports it.
##
## Elements find their group by `puzzle_id`, so builders can place them
## anywhere under the same POI.

var puzzle_id := ""
var _elements: Array[Node] = []


func _ready() -> void:
	add_to_group(&"puzzle_groups")


func is_solved() -> bool:
	return WorldState.flags.has("puzzle_" + puzzle_id)


func register(e: Node) -> void:
	_elements.append(e)


func element_changed() -> void:
	if is_solved():
		return
	for e in _elements:
		if is_instance_valid(e) and not e.is_active():
			return
	WorldState.flags["puzzle_" + puzzle_id] = true
	EventBus.flag_set.emit(StringName("puzzle_" + puzzle_id))
	Audio.play_ui(&"puzzle_solved", -1.0)
	EventBus.toast.emit(tr("TOAST_PUZZLE_SOLVED"))
	for n in get_tree().get_nodes_in_group(&"puzzle_seals"):
		if n.puzzle_id == puzzle_id:
			n.open()


static func find(tree: SceneTree, id: String) -> PuzzleGroup:
	for g in tree.get_nodes_in_group(&"puzzle_groups"):
		if (g as PuzzleGroup).puzzle_id == id:
			return g
	return null
