extends RefCounted
## TEST FIXTURE ONLY — never shipped, never shown in game.
## A minimal rigged scene that follows the character-model conventions
## (humanoid bone names, spring_* hair chain, outfit_/hair_/acc_ meshes,
## named material slots, AnimationPlayer clips) so the unit tests can drive
## the real-model path of EntityVisual without an art asset.
## Boxes stand in for meshes on purpose: this validates plumbing, not looks.

const PATH := "user://ci_character_fixture.tscn"


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "CharacterFixture"
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	root.add_child(skel)
	var bones := [
		["Hips", "", Vector3(0, 0.9, 0)], ["Spine", "Hips", Vector3(0, 0.1, 0)],
		["Chest", "Spine", Vector3(0, 0.15, 0)], ["UpperChest", "Chest", Vector3(0, 0.15, 0)],
		["Neck", "UpperChest", Vector3(0, 0.12, 0)], ["Head", "Neck", Vector3(0, 0.08, 0)],
		["spring_hair_1", "Head", Vector3(0, 0.05, 0.08)], ["spring_hair_2", "spring_hair_1", Vector3(0, -0.15, 0)],
		["spring_hair_3", "spring_hair_2", Vector3(0, -0.15, 0)],
	]
	for side in [["Left", 1.0], ["Right", -1.0]]:
		var n: String = side[0]
		var x: float = side[1]
		bones.append([n + "UpperArm", "UpperChest", Vector3(0.18 * x, 0.05, 0)])
		bones.append([n + "LowerArm", n + "UpperArm", Vector3(0.28 * x, 0, 0)])
		bones.append([n + "Hand", n + "LowerArm", Vector3(0.25 * x, 0, 0)])
		bones.append([n + "UpperLeg", "Hips", Vector3(0.1 * x, -0.05, 0)])
		bones.append([n + "LowerLeg", n + "UpperLeg", Vector3(0, -0.42, 0)])
		bones.append([n + "Foot", n + "LowerLeg", Vector3(0, -0.42, 0)])
	for b in bones:
		var i := skel.add_bone(b[0])
		if b[1] != "":
			skel.set_bone_parent(i, skel.find_bone(b[1]))
		skel.set_bone_rest(i, Transform3D(Basis(), b[2]))
	skel.reset_bone_poses()
	_box(root, "Body", Vector3(0.4, 1.8, 0.25), 0.9, "skin")
	_box(root, "outfit_tunic", Vector3(0.45, 0.7, 0.3), 1.1, "cloth_a")
	_box(root, "outfit_coat", Vector3(0.47, 0.9, 0.32), 1.0, "cloth_a")
	_box(root, "hair_swept", Vector3(0.25, 0.1, 0.25), 1.75, "hair")
	_box(root, "hair_ponytail", Vector3(0.2, 0.3, 0.1), 1.6, "hair")
	_box(root, "acc_scarf", Vector3(0.3, 0.08, 0.3), 1.45, "cloth_b")
	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	root.add_child(anim)
	var lib := AnimationLibrary.new()
	for clip in ["Idle", "Run", "Attack", "Hit", "Death"]:
		var a := Animation.new()
		a.length = 0.5
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("Skeleton3D:Spine"))
		a.rotation_track_insert_key(t, 0.0, Quaternion.IDENTITY)
		a.rotation_track_insert_key(t, 0.5, Quaternion(Vector3.RIGHT, 0.2))
		lib.add_animation(clip, a)
	anim.add_animation_library("", lib)
	for n in root.find_children("*", "", true, false):
		n.owner = root
	return root


static func _box(root: Node3D, nm: String, size: Vector3, y: float, slot: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var m := BoxMesh.new()
	m.size = size
	var mat := StandardMaterial3D.new()
	mat.resource_name = slot
	m.material = mat
	mi.mesh = m
	mi.position.y = y
	root.add_child(mi)


## Packs the fixture to user:// and returns the path (for EntityType.model).
static func save() -> String:
	var root := build()
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return PATH if ResourceSaver.save(ps, PATH) == OK else ""
