class_name SpringBoneChain
extends SkeletonModifier3D
## Lightweight secondary motion for hair locks, braids, scarves, sleeves and
## cloth tails of real rigged characters (CharacterModel.add_springs).
##
## Verlet point per bone tip, pulled back toward the animated pose by
## `stiffness`, lagging with the character's movement and sagging with
## `gravity`; the bone is then rotated to aim at the point. No colliders and
## no cloth solver: cheap enough for mobile (a few bones per NPC), and
## EntityVisual switches it off at distance and on low quality.
## Godot 4.5+ ships SpringBoneSimulator3D; when the project moves to it, the
## same spring_* bone convention maps to it 1:1 (docs/CHARACTER_PIPELINE.md).

@export var root_bone := ""
## 0 = floppy, 1 = rigid (fraction pulled back toward the pose per 1/60 s).
@export_range(0.0, 1.0) var stiffness := 0.18
## Fraction of velocity lost per 1/60 s.
@export_range(0.0, 1.0) var damping := 0.12
@export var gravity := 4.0

var _bones: PackedInt32Array = []
var _tips: Array[Vector3] = []      # tip of each bone, in its own bone space
var _pos: Array[Vector3] = []       # simulated tips, world space
var _prev: Array[Vector3] = []
var _ready_sim := false


func _collect(skel: Skeleton3D) -> void:
	_bones.clear()
	_tips.clear()
	var b := skel.find_bone(root_bone)
	while b >= 0:
		_bones.append(b)
		var kids := skel.get_bone_children(b)
		var next := kids[0] if kids.size() > 0 else -1
		if next >= 0:
			_tips.append(skel.get_bone_rest(next).origin)
		else:
			_tips.append(Vector3(0, maxf(skel.get_bone_rest(b).origin.length(), 0.05), 0))
		b = next
	_pos.resize(_bones.size())
	_prev.resize(_bones.size())
	_ready_sim = false


func reset() -> void:
	_ready_sim = false


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _bones.is_empty():
		_collect(skel)
		if _bones.is_empty():
			return
	var dt := clampf(skel.get_process_delta_time(), 1.0 / 240.0, 1.0 / 20.0)
	var k := dt * 60.0
	var pull := 1.0 - pow(1.0 - stiffness, k)
	var keep := pow(1.0 - damping, k)
	var gxf := skel.global_transform
	var inv_basis := gxf.basis.inverse()
	for i in _bones.size():
		var bi := _bones[i]
		var pose := skel.get_bone_global_pose(bi)
		var head := gxf * pose.origin
		var anim_tip := gxf * (pose * _tips[i])
		var seg := (anim_tip - head).length()
		if seg < 0.0001:
			continue
		if not _ready_sim or _pos[i].distance_to(anim_tip) > seg * 4.0:
			_pos[i] = anim_tip
			_prev[i] = anim_tip
		var p := _pos[i]
		var vel := (p - _prev[i]) * keep
		_prev[i] = p
		p += vel + Vector3(0, -gravity, 0) * dt * dt
		p = p.lerp(anim_tip, pull)
		p = head + (p - head).normalized() * seg
		_pos[i] = p
		var from := (pose.basis * _tips[i]).normalized()
		var to := (inv_basis * (p - head)).normalized()
		if from.is_equal_approx(to):
			continue
		var global_basis := Basis(Quaternion(from, to)) * pose.basis.orthonormalized()
		var parent := skel.get_bone_parent(bi)
		var parent_basis := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
		var local := (parent_basis.inverse() * global_basis).get_rotation_quaternion()
		skel.set_bone_pose_rotation(bi, local)
	_ready_sim = true
