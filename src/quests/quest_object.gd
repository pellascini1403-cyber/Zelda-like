class_name QuestObject
extends Interactable
## Something in the world a quest (or plain curiosity) revolves around:
## a clue to examine, a relic to retrieve, a lever or wind stone to
## activate, a kite stuck on a tower, a chime to ring, a sand obelisk that
## only shows during storms...
##
## Defined in quest data ("spawns", kind "object"): {look, id, group, pos,
## prompt, lines, item, needs_item, needs_count, conditions, hint_key,
## reward, once, consume, sparkle, sound, element, event}. Using it emits
## EventBus.quest_object_used(id, group); a one-shot object records
## WorldState flag "qo:<id>" and never comes back.
##
## Looks are placeholders built from the architecture kit (one mesh, shared
## per kind), replaceable like any other asset.

const KINDS := ["clue", "stone", "relic", "kite", "crate", "scroll", "bell", "lever", "flower", "obelisk", "chime", "offering", "altar", "board", "cage"]

var data: Dictionary = {}
var object_id: StringName = &""
var group: StringName = &""
var _mesh: MeshInstance3D
var _sparkle: GPUParticles3D
static var _meshes: Dictionary = {}


static func create(d: Dictionary) -> QuestObject:
	var o := QuestObject.new()
	o.data = d
	o.object_id = StringName(d.get("id", ""))
	o.group = StringName(d.get("group", ""))
	o.radius = float(d.get("radius", 1.5))
	return o


func _ready() -> void:
	super._ready()
	add_to_group(&"quest_objects")
	var kind := String(data.get("look", "clue"))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh_for(kind)
	_mesh.material_override = WorldMaterials.get_mat(&"architecture")
	_mesh.visibility_range_end = 260.0
	add_child(_mesh)
	if data.get("sparkle", kind in ["clue", "relic", "flower", "chime", "kite", "scroll"]):
		_sparkle = _make_sparkle()
		add_child(_sparkle)
	if kind in ["obelisk", "altar", "stone", "cage"]:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.4, 3.0 if kind != "cage" else 2.2, 1.4) if kind != "altar" else Vector3(2.2, 1.2, 1.4)
		cs.shape = box
		cs.position.y = box.size.y * 0.5
		body.add_child(cs)
		add_child(body)


func prompt_key() -> String:
	return String(data.get("prompt", "PROMPT_EXAMINE"))


func can_interact() -> bool:
	return not used()


func used() -> bool:
	return data.get("once", true) and WorldState.flags.has("qo:" + String(object_id))


func interact(player: Player) -> void:
	if used():
		return
	# Time / weather gates ("only at night", "during a storm").
	var c: Dictionary = data.get("conditions", {})
	if c.has("period") and (c["period"] == "night") != Clock.is_night():
		EventBus.toast.emit(tr(data.get("hint_key", "HINT_WRONG_TIME")))
		return
	if c.has("weather") and not String(Weather.target) in c["weather"]:
		EventBus.toast.emit(tr(data.get("hint_key", "HINT_WRONG_WEATHER")))
		return
	var needs := StringName(data.get("needs_item", ""))
	if needs != &"":
		var n := int(data.get("needs_count", 1))
		if PlayerData.inventory.count_of(needs) < n:
			var it := DB.item(needs)
			EventBus.toast.emit(tr("HINT_NEEDS_ITEM") % [n, tr(it.name_key) if it else String(needs)])
			return
		PlayerData.inventory.remove(needs, n)
	player.start_busy(&"interact", 0.45)
	player.visual.play_action(&"interact", 0.45)
	if data.get("once", true):
		WorldState.flags["qo:" + String(object_id)] = true
	var item := StringName(data.get("item", ""))
	if item != &"":
		var added := PlayerData.inventory.add(item, int(data.get("count", 1)))
		if added > 0:
			EventBus.item_acquired.emit(item, added)
	if data.has("reward"):
		Rewards.grant(data["reward"], "qo:" + String(object_id))
	var lines: Array = data.get("lines", [])
	if not lines.is_empty():
		EventBus.dialogue_requested.emit(String(data.get("speaker", "")), PackedStringArray(lines))
	Audio.play_at(StringName(data.get("sound", "pickup")), global_position, -2.0)
	ElementFX.burst(self, global_position + Vector3.UP * 0.2, StringName(data.get("element", "wind")), 1.4)
	EventBus.quest_object_used.emit(object_id, group)
	if data.has("event"):
		EventBus.quest_event.emit(StringName(data["event"]))
	if data.has("discover"):
		DiscoveryDirector.discover(StringName(data["discover"]))
	if data.get("consume", data.get("once", true) and String(data.get("look", "")) in ["relic", "kite", "crate", "scroll", "flower", "chime"]):
		var t := create_tween()
		t.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		t.tween_callback(queue_free)
	elif _sparkle:
		_sparkle.emitting = false


func _make_sparkle() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = Quality.particle_amount(10)
	p.lifetime = 1.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, 0.3, 0)
	pm.color = Color(1.0, 0.9, 0.55)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = m
	p.draw_pass_1 = quad
	p.position.y = 0.6
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	return p


## Shared placeholder mesh per kind (built once).
static func mesh_for(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var k := StructureKit.new(hash(kind))
	var b := k.b
	match kind:
		"clue":
			k.rock(Vector3(0, 0.25, 0), Vector3(0.5, 0.35, 0.45), StructureKit.COOL_STONE, false)
			StructureKit.box_into(b, Transform3D(Basis(), Vector3(0, 0.42, 0)), Vector3(0.62, 0.06, 0.5), StructureKit.id(StructureKit.JADE, StructureKit.LAMP))
		"stone":
			StructureKit.prism_into(b, Vector3.ZERO, Vector3(0, 2.6, 0), 0.55, 0.35, 5, StructureKit.id(StructureKit.WHITE_STONE, StructureKit.MATTE))
			StructureKit.prism_into(b, Vector3(0, 1.4, 0), Vector3(0, 1.6, 0), 0.52, 0.5, 5, StructureKit.id(StructureKit.JADE, StructureKit.LAMP))
		"relic":
			StructureKit.prism_into(b, Vector3.ZERO, Vector3(0, 0.6, 0), 0.4, 0.34, 6, StructureKit.id(StructureKit.WHITE_STONE, StructureKit.MATTE))
			b.blob(Vector3(0, 0.85, 0), Vector3(0.18, 0.26, 0.18), StructureKit.id(StructureKit.GOLD, StructureKit.GILT), StructureKit.id(StructureKit.GOLD * 0.8, StructureKit.GILT), 0, 0.1, 3)
		"kite":
			for t in [b, k.far]:
				StructureKit.qf(t, Vector3(0, 0.1, 0), Vector3(0.5, 0.7, 0), Vector3(0, 1.4, 0), Vector3(-0.5, 0.7, 0), StructureKit.id(StructureKit.CINNABAR_LIGHT, StructureKit.CLOTH), Vector3(0, 0, 1))
				StructureKit.qf(t, Vector3(0, 0.1, 0), Vector3(0.5, 0.7, 0), Vector3(0, 1.4, 0), Vector3(-0.5, 0.7, 0), StructureKit.id(StructureKit.GOLD, StructureKit.CLOTH), Vector3(0, 0, -1))
			k.ribbon(Vector3(0, 0.1, 0), 1.2, 0.1, StructureKit.JADE)
		"crate":
			StructureKit.box_into(b, Transform3D(Basis(), Vector3(0, 0.4, 0)), Vector3(0.8, 0.8, 0.8), StructureKit.id(Color(0.62, 0.45, 0.28), StructureKit.MATTE))
			StructureKit.box_into(b, Transform3D(Basis(), Vector3(0, 0.4, 0)), Vector3(0.84, 0.12, 0.84), StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
		"scroll":
			StructureKit.prism_into(b, Vector3(-0.25, 0.1, 0), Vector3(0.25, 0.1, 0), 0.07, 0.07, 6, StructureKit.id(StructureKit.PAPER, StructureKit.MATTE))
			StructureKit.box_into(b, Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(0.12, 0.16, 0.16), StructureKit.id(StructureKit.CINNABAR, StructureKit.MATTE))
		"bell":
			StructureKit.prism_into(b, Vector3(-0.8, 0, 0), Vector3(-0.8, 2.4, 0), 0.08, 0.08, 4, StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
			StructureKit.prism_into(b, Vector3(0.8, 0, 0), Vector3(0.8, 2.4, 0), 0.08, 0.08, 4, StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
			StructureKit.box_into(b, Transform3D(Basis(), Vector3(0, 2.4, 0)), Vector3(1.9, 0.14, 0.14), StructureKit.id(StructureKit.CINNABAR, StructureKit.MATTE))
			StructureKit.prism_into(b, Vector3(0, 2.3, 0), Vector3(0, 1.5, 0), 0.18, 0.42, 8, StructureKit.id(StructureKit.GOLD * 0.8, StructureKit.GILT))
		"lever":
			StructureKit.box_into(b, Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(0.7, 0.6, 0.5), StructureKit.id(StructureKit.COOL_STONE, StructureKit.MATTE))
			StructureKit.prism_into(b, Vector3(0, 0.6, 0), Vector3(0.25, 1.4, 0), 0.05, 0.05, 4, StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
			b.blob(Vector3(0.25, 1.45, 0), Vector3(0.1, 0.1, 0.1), StructureKit.id(StructureKit.CINNABAR, StructureKit.MATTE), StructureKit.id(StructureKit.CINNABAR, StructureKit.MATTE), 0, 0.0, 1)
		"flower":
			StructureKit.prism_into(b, Vector3.ZERO, Vector3(0, 0.5, 0), 0.02, 0.02, 3, StructureKit.id(StructureKit.JADE, StructureKit.MATTE))
			b.blob(Vector3(0, 0.55, 0), Vector3(0.16, 0.08, 0.16), StructureKit.id(Color(0.75, 0.9, 1.0), StructureKit.LAMP), StructureKit.id(Color(0.5, 0.7, 1.0), StructureKit.LAMP), 0, 0.1, 2)
		"obelisk":
			StructureKit.prism_into(b, Vector3.ZERO, Vector3(0, 0.5, 0), 1.0, 0.9, 4, StructureKit.id(Color(0.78, 0.6, 0.42), StructureKit.MATTE))
			StructureKit.prism_into(b, Vector3(0, 0.5, 0), Vector3(0, 4.6, 0), 0.5, 0.28, 4, StructureKit.id(Color(0.84, 0.66, 0.46), StructureKit.MATTE))
			StructureKit.prism_into(b, Vector3(0, 3.2, 0), Vector3(0, 3.5, 0), 0.4, 0.38, 4, StructureKit.id(StructureKit.GOLD, StructureKit.LAMP))
		"chime":
			StructureKit.prism_into(b, Vector3.ZERO, Vector3(0, 1.9, 0), 0.05, 0.05, 4, StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
			StructureKit.box_into(b, Transform3D(Basis(), Vector3(0.25, 1.9, 0)), Vector3(0.6, 0.05, 0.05), StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
			for i in 4:
				StructureKit.prism_into(b, Vector3(0.05 + i * 0.13, 1.85, 0), Vector3(0.05 + i * 0.13, 1.4 - i * 0.06, 0), 0.025, 0.025, 4, StructureKit.id(Color(0.55, 0.85, 0.66), StructureKit.GILT))
			k.ribbon(Vector3(0.5, 1.88, 0), 0.9, 0.08, StructureKit.CINNABAR_LIGHT)
		"offering":
			StructureKit.prism_into(b, Vector3.ZERO, Vector3(0, 0.7, 0), 0.5, 0.4, 8, StructureKit.id(StructureKit.WHITE_STONE, StructureKit.MATTE))
			StructureKit.prism_into(b, Vector3(0, 0.7, 0), Vector3(0, 0.95, 0), 0.35, 0.55, 8, StructureKit.id(StructureKit.GOLD * 0.7, StructureKit.GILT))
		"altar":
			StructureKit.box_into(b, Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(2.2, 0.9, 1.3), StructureKit.id(StructureKit.WHITE_STONE, StructureKit.MATTE))
			StructureKit.box_into(b, Transform3D(Basis(), Vector3(0, 0.95, 0)), Vector3(2.4, 0.12, 1.5), StructureKit.id(StructureKit.JADE, StructureKit.GLAZE))
			StructureKit.prism_into(b, Vector3(0, 1.0, 0), Vector3(0, 1.6, 0), 0.22, 0.12, 6, StructureKit.id(Color(0.55, 0.85, 0.66), StructureKit.LAMP))
		"board":
			StructureKit.prism_into(b, Vector3(-0.9, 0, 0), Vector3(-0.9, 2.2, 0), 0.07, 0.07, 4, StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
			StructureKit.prism_into(b, Vector3(0.9, 0, 0), Vector3(0.9, 2.2, 0), 0.07, 0.07, 4, StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
			StructureKit.box_into(b, Transform3D(Basis(), Vector3(0, 1.5, 0)), Vector3(1.9, 1.1, 0.08), StructureKit.id(Color(0.55, 0.4, 0.26), StructureKit.MATTE))
			for i in 3:
				StructureKit.box_into(b, Transform3D(Basis(), Vector3(-0.55 + i * 0.55, 1.5, 0.06)), Vector3(0.4, 0.55, 0.02), StructureKit.id(StructureKit.PAPER, StructureKit.MATTE))
			StructureKit.box_into(b, Transform3D(Basis(), Vector3(0, 2.2, 0)), Vector3(2.3, 0.14, 0.4), StructureKit.id(StructureKit.ROOF, StructureKit.GLAZE))
		"cage":
			for i in 8:
				var a := TAU * i / 8.0
				StructureKit.prism_into(b, Vector3(cos(a), 0, sin(a)) * 0.8, Vector3(cos(a) * 0.8, 2.0, sin(a) * 0.8), 0.05, 0.05, 4, StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
			StructureKit.prism_into(b, Vector3(0, 2.0, 0), Vector3(0, 2.2, 0), 0.95, 0.4, 8, StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
		_:
			k.rock(Vector3(0, 0.3, 0), Vector3(0.4, 0.3, 0.4), StructureKit.COOL_STONE, false)
	var m := b.commit()
	_meshes[kind] = m
	return m
