class_name CharacterModel
extends RefCounted
## Integration of real, rigged 3D character models (glTF/FBX scenes) into
## EntityVisual. Everything here works from naming conventions so a model
## delivered later drops in without code changes. See docs/CHARACTER_PIPELINE.md.
##
## PROJECT RULE: final human characters are real modelled assets (anatomy,
## face, hair, clothes, rig, animations). They are never built from code
## primitives; MannequinBuilder stays a frozen technical placeholder.

## Bone names follow Godot's SkeletonProfileHumanoid (the importer's BoneMap
## renames any rig — Mixamo, Rigify, UE, VRM — to these).
const REQUIRED_BONES := [
	"Hips", "Spine", "Chest", "Neck", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
]
const OPTIONAL_BONES := [
	"Root", "UpperChest", "LeftShoulder", "RightShoulder", "LeftToes", "RightToes",
	"LeftEye", "RightEye", "Jaw",
]
## Gameplay sockets -> bone (first existing one wins). A `socket_<name>` node
## in the model always takes precedence.
const SOCKET_BONES := {
	&"hand_r": ["RightHand"],
	&"hand_l": ["LeftHand"],
	&"head": ["Head"],
	&"back": ["UpperChest", "Chest", "Spine"],
	&"center": ["Hips"],
}
## Mesh groups chosen from the visual profile (data/visuals.json). A model
## may hold several meshes per group (outfit_tunic, outfit_coat...); only the
## selected one stays visible. Groups the model does not use are ignored.
const GROUPS := {"outfit_": "outfit", "hair_": "hair", "headwear_": "headwear", "acc_": "accessories"}
## Bones whose name starts with this get secondary motion (hair, cloth tails).
const SPRING_PREFIX := "spring_"
## Material slots (material resource_name prefix) that a palette may tint.
const TINT_SLOTS := ["skin", "hair", "eyes", "cloth_a", "cloth_b", "leather", "metal"]

## Mobile budgets (docs/CHARACTER_PIPELINE.md). The check tool warns above them.
const BUDGET := {
	"PLAYER": {"tris": 20000, "bones": 75, "materials": 4},
	"NPC": {"tris": 10000, "bones": 65, "materials": 3},
	"ENEMY": {"tris": 8000, "bones": 60, "materials": 2},
	"BOSS": {"tris": 30000, "bones": 90, "materials": 4},
	"ANIMAL": {"tris": 6000, "bones": 50, "materials": 2},
}

static var _tinted: Dictionary = {}


static func find_skeleton(model: Node) -> Skeleton3D:
	if model is Skeleton3D:
		return model
	return _first_of(model, "Skeleton3D") as Skeleton3D


static func _first_of(root: Node, cls: String) -> Node:
	var found := root.find_children("*", cls, true, false)
	return found[0] if not found.is_empty() else null


static func meshes(model: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in model.find_children("*", "MeshInstance3D", true, false):
		out.append(n)
	return out


## Height of the model's visible meshes (rest pose), in model space.
static func rest_aabb(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in meshes(model):
		if mi.mesh == null or not mi.visible:
			continue
		var xf := model.global_transform.affine_inverse() * mi.global_transform if mi.is_inside_tree() else _local_xf(model, mi)
		var b: AABB = xf * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _local_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Scale that makes the model as tall as the gameplay collider (feet at 0).
static func fit_scale(model: Node3D, height: float) -> float:
	var box := rest_aabb(model)
	if box.size.y <= 0.001:
		return 1.0
	return height / box.size.y


## Gameplay sockets bound to bones (BoneAttachment3D), unless the model
## already ships socket_<name> nodes.
static func bind_sockets(skel: Skeleton3D, existing: Dictionary) -> Dictionary:
	var out := {}
	for s in SOCKET_BONES:
		if existing.has(s):
			continue
		for bone in SOCKET_BONES[s]:
			if skel.find_bone(bone) >= 0:
				var att := BoneAttachment3D.new()
				att.name = "socket_" + String(s)
				att.bone_name = bone
				skel.add_child(att)
				out[s] = att
				break
	return out


## Show the outfit / hair / headwear / accessories the profile selects.
## A group whose selection is missing keeps its first mesh, so a model with a
## single outfit always shows it.
static func apply_variant(model: Node, profile: Dictionary) -> void:
	for prefix in GROUPS:
		var key: String = GROUPS[prefix]
		var members: Array[Node3D] = []
		for n in model.find_children(prefix + "*", "Node3D", true, false):
			members.append(n)
		if members.is_empty():
			continue
		var wanted: Array = profile.get(key, []) if profile.get(key) is Array else [profile.get(key, "")]
		var any := false
		for n in members:
			var id := String(n.name).trim_prefix(prefix)
			n.visible = id in wanted
			any = any or n.visible
		if not any and key != "accessories" and key != "headwear":
			members[0].visible = true


## Per-NPC palette on tintable material slots. Opt-in (entities.json
## model_options.palette): a model is never recoloured unless asked. Tinted
## copies are shared between NPCs with the same colour, so 20 villagers with
## 4 palettes cost 4 materials, not 20.
static func apply_palette(model: Node, palette: Dictionary) -> int:
	if palette.is_empty():
		return 0
	var changed := 0
	for mi in meshes(model):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat == null:
				continue
			var slot := slot_of(mat)
			if slot == "" or not palette.has(slot):
				continue
			var c := Color(palette[slot])
			var key := "%d|%s" % [mat.get_instance_id(), c.to_html()]
			if not _tinted.has(key):
				var copy: Material = mat.duplicate()
				if copy is BaseMaterial3D:
					(copy as BaseMaterial3D).albedo_color = c
				elif copy is ShaderMaterial:
					(copy as ShaderMaterial).set_shader_parameter("tint", c)
				_tinted[key] = copy
			mi.set_surface_override_material(s, _tinted[key])
			changed += 1
	return changed


static func slot_of(mat: Material) -> String:
	var nm := mat.resource_name.to_lower()
	for slot in TINT_SLOTS:
		if nm == slot or nm.begins_with(slot + "_") or nm.begins_with(slot + "."):
			return slot
	return ""


## Adds a SpringBoneChain for every chain root (spring_* bone whose parent is
## not spring_*), plus explicit roots listed in model_options.spring_bones.
static func add_springs(skel: Skeleton3D, options: Dictionary) -> Array[SpringBoneChain]:
	var roots: Array[int] = []
	for i in skel.get_bone_count():
		var nm := skel.get_bone_name(i)
		var parent := skel.get_bone_parent(i)
		if nm.begins_with(SPRING_PREFIX) and (parent < 0 or not skel.get_bone_name(parent).begins_with(SPRING_PREFIX)):
			roots.append(i)
	for nm in options.get("spring_bones", []):
		var i := skel.find_bone(String(nm))
		if i >= 0 and not i in roots:
			roots.append(i)
	var out: Array[SpringBoneChain] = []
	var cfg: Dictionary = options.get("spring", {})
	for r in roots:
		var chain := SpringBoneChain.new()
		chain.name = "Spring_" + skel.get_bone_name(r)
		chain.root_bone = skel.get_bone_name(r)
		chain.stiffness = cfg.get("stiffness", chain.stiffness)
		chain.damping = cfg.get("damping", chain.damping)
		chain.gravity = cfg.get("gravity", chain.gravity)
		skel.add_child(chain)
		out.append(chain)
	return out


## Report used by `-- --check-model` and the unit tests.
static func analyze(model: Node3D, e: EntityType = null) -> Dictionary:
	var rep := {"errors": [], "warnings": [], "bones": 0, "tris": 0, "materials": [], "clips": [], "groups": {}, "springs": []}
	var skel := find_skeleton(model)
	if skel == null:
		rep.errors.append("no Skeleton3D: final characters must be rigged")
	else:
		rep.bones = skel.get_bone_count()
		for b in REQUIRED_BONES:
			if skel.find_bone(b) < 0:
				rep.errors.append("missing bone '%s' (map the rig to SkeletonProfileHumanoid in the import dialog)" % b)
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).begins_with(SPRING_PREFIX):
				rep.springs.append(skel.get_bone_name(i))
	var mats := {}
	for mi in meshes(model):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s) if mi.mesh is ArrayMesh or mi.mesh is PrimitiveMesh else []
			if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null and (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0:
				rep.tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			elif arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
				rep.tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var m := mi.get_active_material(s)
			if m:
				mats[m.resource_name if m.resource_name != "" else "<unnamed>"] = true
		for prefix in GROUPS:
			if String(mi.name).begins_with(prefix):
				rep.groups[String(mi.name)] = true
	rep.materials = mats.keys()
	var anim := _first_of(model, "AnimationPlayer") as AnimationPlayer
	if anim == null:
		rep.errors.append("no AnimationPlayer: export the clips with the model (or in a shared animation library)")
	else:
		for c in anim.get_animation_list():
			rep.clips.append(String(c))
	var box := rest_aabb(model)
	rep.height = box.size.y
	if box.size.y > 0.0 and absf(box.position.y) > box.size.y * 0.05:
		rep.warnings.append("origin is not at the feet (lowest point y=%.2f)" % box.position.y)
	if e:
		var kind: String = EntityType.Kind.keys()[e.kind]
		var bud: Dictionary = BUDGET.get(kind, BUDGET.NPC)
		if rep.tris > bud.tris:
			rep.warnings.append("%d triangles > %d budget for %s (add LODs or reduce)" % [rep.tris, bud.tris, kind])
		if rep.bones > bud.bones:
			rep.warnings.append("%d bones > %d budget for %s" % [rep.bones, bud.bones, kind])
		if rep.materials.size() > bud.materials:
			rep.warnings.append("%d materials > %d budget for %s (atlas them)" % [rep.materials.size(), bud.materials, kind])
		var fit: bool = e.model_options.get("fit_height", false)
		var h: float = box.size.y * (1.0 if fit else e.model_scale)
		if not fit and box.size.y > 0.0 and absf(h - e.collider_height) > e.collider_height * 0.15:
			rep.warnings.append("model height %.2f m vs collider %.2f m: set model_scale or model_options.fit_height" % [h, e.collider_height])
		var missing := []
		for l in [&"idle", &"move", &"attack", &"hit", &"die"]:
			var clip: String = e.anim_map.get(String(l), String(l))
			if anim == null or not anim.has_animation(clip):
				missing.append(String(l))
		if not missing.is_empty():
			rep.warnings.append("core states without a clip (anim_map): %s" % ", ".join(missing))
	return rep
