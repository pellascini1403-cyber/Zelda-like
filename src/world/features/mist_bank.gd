class_name MistBank
extends Node3D
## A bank of sea mist with edges: thick inside, thin at its rim, clear in its
## pockets (around the sea stacks, the bell sanctuary). From outside it reads
## as a pale wall on the horizon; inside, the view closes to a few tens of
## metres and you steer by bells, lights and silhouettes.
## Its own clock: thick from dusk to mid-morning, thin on clear afternoons,
## thickest in foggy weather, torn thin by storm winds.
## The environment controller asks `density_at(camera)` for the fog; the
## Mistwalker's lantern ("mist_sight" gear) and clearsight tea let you see
## further.

const WALLS := 16

var radius := 300.0
var edge := 70.0
## [[x, z, radius], ...] in world coordinates: clear pockets inside the bank.
var pockets: Array = []
var _walls: Array[MeshInstance3D] = []
static var _wall_mat: ShaderMaterial


static func create(r: float, e: float, clear: Array) -> MistBank:
	var m := MistBank.new()
	m.radius = r
	m.edge = e
	m.pockets = clear
	return m


## Time/weather strength of every bank (0..1).
static func intensity(hour: float = -1.0) -> float:
	var h := Clock.hour if hour < 0.0 else hour
	var v := 1.0
	if h >= 8.0 and h < 11.0:
		v = lerpf(1.0, 0.1, (h - 8.0) / 3.0)
	elif h >= 11.0 and h < 17.0:
		v = 0.1
	elif h >= 17.0 and h < 20.0:
		v = lerpf(0.1, 1.0, (h - 17.0) / 3.0)
	v = maxf(v, Weather.fog)
	v = minf(v + Weather.rain * 0.25, 1.0)
	v *= lerpf(1.0, 0.35, Weather.storm)
	return v


## Mist density at a point (0 = clear air, 1 = the heart of a thick bank).
static func density_at(pos: Vector3, tree: SceneTree) -> float:
	if tree == null:
		return 0.0
	var best := 0.0
	for n in tree.get_nodes_in_group(&"mist_banks"):
		best = maxf(best, (n as MistBank).local(pos))
	return best * intensity()


## The same, as the player sees it (gear can pierce the mist).
static func seen_density(pos: Vector3, tree: SceneTree) -> float:
	var sight := PlayerData.armor_bonus("mist_sight") + PlayerData.buff_potency(&"mist_sight") * 0.3
	return density_at(pos, tree) * clampf(1.0 - sight, 0.2, 1.0)


func local(pos: Vector3) -> float:
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	if d > radius:
		return 0.0
	var k := 1.0 - smoothstep(radius - edge, radius, d)
	for pk in pockets:
		var pd := Vector2(pos.x - float(pk[0]), pos.z - float(pk[1])).length()
		var pr := float(pk[2])
		k *= smoothstep(pr * 0.45, pr, pd)
	# Low mist: it hugs the water; from a cliff or a glide you look over it.
	var above := pos.y - WorldGen.SEA_LEVEL
	k *= 1.0 - smoothstep(18.0, 40.0, above)
	return k


func _ready() -> void:
	add_to_group(&"mist_banks")
	if _wall_mat == null:
		_wall_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform float strength = 1.0;
global uniform vec3 mist_color;
varying float cam_dist;
void vertex() {
	cam_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
void fragment() {
	float side = 1.0 - pow(abs(UV.x * 2.0 - 1.0), 2.0);
	float up = pow(1.0 - UV.y, 1.6) * smoothstep(0.0, 0.08, 1.0 - UV.y);
	// Fades out as you enter it: the fog takes over from the wall.
	float near = smoothstep(35.0, 140.0, cam_dist);
	ALBEDO = mist_color * 1.05 + vec3(0.06);
	ALPHA = side * up * near * strength * 0.72;
}
"""
		_wall_mat.shader = sh
	# A ring of soft walls just inside the rim: the bank's silhouette.
	for i in WALLS:
		var a := TAU * float(i) / WALLS
		var q := QuadMesh.new()
		q.size = Vector2(radius * TAU / WALLS * 1.35, 30.0)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = _wall_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var r := radius - edge * 0.6
		mi.position = Vector3(cos(a) * r, 13.0, sin(a) * r)
		mi.rotation.y = -a + PI * 0.5
		mi.visibility_range_end = 1500.0
		add_child(mi)
		_walls.append(mi)


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 30 != 0:
		return
	var s := intensity()
	_wall_mat.set_shader_parameter(&"strength", s)
	for w in _walls:
		w.visible = s > 0.05
