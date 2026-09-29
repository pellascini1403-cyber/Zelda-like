class_name ElementFX
extends MeshInstance3D
## Pooled expanding shockwave rings + a matching particle burst, tinted by
## element. Used by slams, eruptions, parries, boss phase shifts, ability
## casts. One quad + one pooled CPUParticles3D per burst.

const POOL := 10
const COLORS := {
	&"": Color(1.0, 0.82, 0.55),
	&"fire": Color(1.0, 0.45, 0.15),
	&"ice": Color(0.55, 0.85, 1.0),
	&"electric": Color(0.75, 0.6, 1.0),
	&"wind": Color(0.6, 1.0, 0.85),
	&"sand": Color(1.0, 0.78, 0.45),
	&"glass": Color(0.45, 0.95, 1.0),
	&"still": Color(0.85, 0.45, 1.0),
	&"thorn": Color(0.75, 1.0, 0.35),
	&"jade": Color(0.4, 1.0, 0.7),
}

static var _pool: Array[ElementFX] = []
static var _root: Node3D

var _t := 0.0
var _life := 0.5
var _mat: ShaderMaterial


static func color(element: StringName) -> Color:
	return COLORS.get(element, COLORS[&""])


static func _ensure(ctx: Node) -> bool:
	if _root != null and is_instance_valid(_root) and _root.is_inside_tree():
		return true
	if ctx == null or not ctx.is_inside_tree():
		return false
	_pool.clear()
	_root = Node3D.new()
	_root.name = "ShockwavePool"
	ctx.get_tree().current_scene.add_child(_root)
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var shader: Shader = load("res://assets/shaders/shockwave.gdshader")
	for i in POOL:
		var fx := ElementFX.new()
		fx.mesh = quad
		fx._mat = ShaderMaterial.new()
		fx._mat.shader = shader
		fx.material_override = fx._mat
		fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx.visible = false
		fx.set_process(false)
		_root.add_child(fx)
		_pool.append(fx)
	return true


static func _take(ctx: Node) -> ElementFX:
	if not _ensure(ctx):
		return null
	for fx in _pool:
		if not fx.visible:
			return fx
	return _pool[0]


## Ground ring + particles at `pos` (radius in metres).
static func burst(ctx: Node, pos: Vector3, element: StringName = &"", radius: float = 2.0) -> void:
	var col := color(element)
	var fx := _take(ctx)
	if fx:
		fx._play(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3(radius, radius, radius)), pos + Vector3.UP * 0.15), col, 0.45)
	Effects.sparks(ctx, pos + Vector3.UP * 0.4, col, 0.4)


## Vertical ring facing the camera (parries, hits in the air).
static func ring(ctx: Node, pos: Vector3, element: StringName = &"", radius: float = 1.2, life: float = 0.3) -> void:
	var fx := _take(ctx)
	if fx == null:
		return
	var cam := ctx.get_viewport().get_camera_3d() if ctx.is_inside_tree() else null
	var basis := Basis()
	if cam:
		basis = cam.global_basis
	fx._play(Transform3D(basis.scaled(Vector3(radius, radius, radius)), pos), color(element), life)


func _play(xf: Transform3D, col: Color, life: float) -> void:
	global_transform = xf
	_mat.set_shader_parameter("tint", col)
	_mat.set_shader_parameter("t", 0.0)
	_t = 0.0
	_life = life
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	_mat.set_shader_parameter("t", clampf(_t / _life, 0.0, 1.0))
	if _t >= _life:
		visible = false
		set_process(false)
