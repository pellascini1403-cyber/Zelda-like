class_name VehicleVisual
extends Node3D
## Presentation of a premium vehicle (Vantrel Works). The ONLY node that knows
## what a vehicle looks like; Vehicle (gameplay) talks to it through:
##   update_motion(speed, steer, lean, grounded, delta)   set_water_blend(t)
##   set_charge(t)   recoil()   muzzles()   seat()   set_headlamp(on)   set_flash()
##
## With data "model" empty, an original procedural placeholder is built from
## the brand kit: worn silver panels, black wheels, black glass, soot-iron
## mechanics, the cut-disc badge, hex-bolt triplets and three-groove bands.
## Static parts are merged per material (few draw calls on mobile).
## With a model path, the user's scene is instanced as-is; nodes named
## wheel_front / wheel_rear / wheel_main / steer / float_collar / propeller
## and socket_seat / socket_muzzle_* are driven if present (docs/VEHICLES.md).

const FAR := 220.0      # whole vehicle
const DETAIL := 45.0    # small mechanical detail

var def: Dictionary
var is_placeholder := true
var lean_node: Node3D
var body: Node3D
var steer_node: Node3D
var wheels: Array[Node3D] = []        # spun by speed
var wheel_radius: Array[float] = []
var _seat: Node3D
var _muzzles: Array[Node3D] = []
var _retract: Node3D                  # capsule: wheel assembly that folds up
var _outriggers: Array[Node3D] = []
var _collar: Node3D
var _prop: Node3D
var _lamp: SpotLight3D
var _geoms: Array[GeometryInstance3D] = []
var _groups: Dictionary = {}          # Node3D -> {mat_key: SurfaceTool}
var _lean := 0.0
var _recoil := 0.0
var _charge := 0.0
var _water := 0.0

static var _mats: Dictionary = {}


func setup(d: Dictionary) -> void:
	def = d
	for c in get_children():
		c.queue_free()
	wheels.clear()
	wheel_radius.clear()
	_muzzles.clear()
	_outriggers.clear()
	_geoms.clear()
	lean_node = Node3D.new()
	lean_node.name = "Lean"
	add_child(lean_node)
	var model := String(d.get("model", ""))
	if model != "" and ResourceLoader.exists(model):
		_build_model(model)
	else:
		match String(d.get("class", "")):
			"heavy": _longwake()
			"light": _sparrow()
			"capsule": _bellhull()
		_commit()
	if _seat == null:
		_seat = _socket(lean_node, "seat", _v(d.get("seat", [0, 1, 0])))


# --- Final model -------------------------------------------------------------------------------
func _build_model(path: String) -> void:
	is_placeholder = false
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	inst.scale = Vector3.ONE * float(def.get("model_scale", 1.0))
	inst.position = _v(def.get("model_offset", [0, 0, 0]))
	lean_node.add_child(inst)
	body = inst
	for n in inst.find_children("*", "Node3D", true, false):
		match String(n.name):
			"wheel_front", "wheel_rear", "wheel_main":
				wheels.append(n)
				wheel_radius.append(0.4)
			"steer": steer_node = n
			"float_collar": _collar = n
			"propeller": _prop = n
			"wheel_assembly": _retract = n
			"socket_seat": _seat = n
		if String(n.name).begins_with("socket_muzzle"):
			_muzzles.append(n)
	for g in inst.find_children("*", "GeometryInstance3D", true, false):
		_geoms.append(g)


# --- Brand kit ---------------------------------------------------------------------------------
static func mat(key: String, wear: float = 0.55) -> Material:
	var k := "%s|%.2f" % [key, wear] if key == "silver" else key
	if _mats.has(k):
		return _mats[k]
	var m: Material
	match key:
		"silver":
			var sm := ShaderMaterial.new()
			sm.shader = preload("res://assets/shaders/vehicle_metal.gdshader")
			sm.set_shader_parameter("wear", wear)
			m = sm
		"dark":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.13, 0.13, 0.14)
			s.metallic = 0.55
			s.roughness = 0.58
			m = s
		"rubber":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.045, 0.045, 0.05)
			s.roughness = 0.93
			m = s
		"glass":
			# Black glass: near-black, glossy, only reflections read.
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.012, 0.014, 0.018)
			s.metallic = 0.25
			s.roughness = 0.06
			s.metallic_specular = 0.9
			m = s
		"lamp":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.2, 0.18, 0.14)
			s.emission_enabled = true
			s.emission = Color(1.0, 0.86, 0.62)
			s.emission_energy_multiplier = 0.35
			m = s
		"amber":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.3, 0.16, 0.02)
			s.emission_enabled = true
			s.emission = Color(1.0, 0.55, 0.12)
			s.emission_energy_multiplier = 0.8
			m = s
	_mats[k] = m
	return m


## Night: every headlamp lens brightens (one shared material).
static func set_night(night: bool) -> void:
	var m := mat("lamp") as StandardMaterial3D
	m.emission_energy_multiplier = 2.6 if night else 0.35


static func _v(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(arr[0], arr[1], arr[2])


static func xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl), pos)


## Queues a primitive into `node`'s merged mesh for material `key`.
func add(node: Node3D, key: String, mesh: Mesh, t: Transform3D) -> void:
	if not _groups.has(node):
		_groups[node] = {}
	var g: Dictionary = _groups[node]
	if not g.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		g[key] = st
	(g[key] as SurfaceTool).append_from(mesh, 0, t)


func _commit() -> void:
	var wear := float(def.get("wear", 0.55))
	for node: Node3D in _groups:
		var g: Dictionary = _groups[node]
		for key: String in g:
			var st: SurfaceTool = g[key]
			var mi := MeshInstance3D.new()
			mi.name = "M_" + key
			mi.mesh = st.commit()
			mi.material_override = mat(key, wear)
			var small := node != body and node != lean_node and not node in wheels and node != _retract
			mi.visibility_range_end = DETAIL if small else FAR
			if key in ["glass", "lamp", "amber"] or small:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mi)
			_geoms.append(mi)
	_groups.clear()


func _node(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = n
	node.position = pos
	parent.add_child(node)
	return node


func _socket(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	return _node(parent, "socket_" + n, pos)


## Black wheel: rubber tyre (optional knobs), soot-iron hub, spun on X.
func _wheel(parent: Node3D, n: String, pos: Vector3, r: float, w: float, knobby: bool, hub: float) -> Node3D:
	var wn := _node(parent, n, pos)
	add(wn, "rubber", ShapeKit.cyl(r, r, w, 22), xf(Vector3.ZERO, Vector3(0, 0, 90)))
	add(wn, "dark", ShapeKit.cyl(hub, hub, w + 0.03, 12), xf(Vector3.ZERO, Vector3(0, 0, 90)))
	add(wn, "dark", ShapeKit.cyl(hub * 0.35, hub * 0.35, w + 0.08, 6), xf(Vector3.ZERO, Vector3(0, 0, 90)))
	# Hub cut-outs: five dark bolts, the brand's ring of hardware.
	for i in 5:
		var a := TAU * i / 5.0
		add(wn, "rubber", ShapeKit.cyl(hub * 0.12, hub * 0.12, w + 0.05, 6), xf(Vector3(0, cos(a) * hub * 0.62, sin(a) * hub * 0.62), Vector3(0, 0, 90)))
	if knobby:
		for i in 14:
			var a := TAU * i / 14.0
			add(wn, "rubber", ShapeKit.box(Vector3(w * 0.9, r * 0.12, r * 0.16)), xf(Vector3(0, cos(a) * r, sin(a) * r), Vector3(rad_to_deg(-a), 0, 0)))
	wheels.append(wn)
	wheel_radius.append(r)
	return wn


## Cut-disc badge (a soot disc split by a silver chevron) facing `side`.
func _badge(node: Node3D, pos: Vector3, side: float, s: float = 1.0) -> void:
	add(node, "dark", ShapeKit.cyl(0.09 * s, 0.09 * s, 0.02, 10), xf(pos, Vector3(0, 0, 90)))
	for k in [-1.0, 1.0]:
		add(node, "silver", ShapeKit.box(Vector3(0.012, 0.03 * s, 0.1 * s)), xf(pos + Vector3(side * 0.012, 0.012 * s * k, 0), Vector3(k * 35.0, 0, 0)))
	_bolts(node, pos + Vector3(0, -0.13 * s, 0), side, s)


## Hex-bolt triplet (brand hardware).
func _bolts(node: Node3D, pos: Vector3, side: float, s: float = 1.0) -> void:
	for i in 3:
		add(node, "dark", ShapeKit.cyl(0.014 * s, 0.014 * s, 0.018, 6), xf(pos + Vector3(side * 0.004, 0, (i - 1) * 0.05 * s), Vector3(0, 0, 90)))


## Three thin soot grooves: the recurring panel line of the brand.
func _grooves(node: Node3D, a: Vector3, length: float, side: float, axis_z: bool = true) -> void:
	for i in 3:
		var p := a + Vector3(0, -i * 0.035, 0)
		add(node, "dark", ShapeKit.box(Vector3(0.01, 0.012, length) if axis_z else Vector3(length, 0.012, 0.01)), xf(p + Vector3(side * 0.005, 0, 0)))


# --- 01 Longwake: heavy, long, low, a tall leaning prow ------------------------------------------
## Silhouette: a long low keel, stepped carapace plates rising to a short
## rear cowl, side pontoons along the big rear wheel, and a tall forward-
## leaning twin-blade prow carrying a black visor over an EXPOSED front wheel.
func _longwake() -> void:
	body = _node(lean_node, "Body", Vector3.ZERO)
	var b := body
	add(b, "dark", ShapeKit.box(Vector3(0.62, 0.26, 2.1)), xf(Vector3(0, 0.42, 0.05)))
	add(b, "silver", ShapeKit.box(Vector3(1.04, 0.2, 1.45)), xf(Vector3(0, 0.62, 0.3)))
	add(b, "silver", ShapeKit.box(Vector3(0.9, 0.16, 1.05)), xf(Vector3(0, 0.79, 0.45), Vector3(-3, 0, 0)))
	add(b, "silver", ShapeKit.box(Vector3(0.84, 0.36, 0.55)), xf(Vector3(0, 0.98, 0.95), Vector3(-14, 0, 0)))
	add(b, "silver", ShapeKit.box(Vector3(0.6, 0.12, 0.35)), xf(Vector3(0, 1.2, 1.05), Vector3(-24, 0, 0)))
	add(b, "dark", ShapeKit.box(Vector3(0.46, 0.12, 0.62)), xf(Vector3(0, 0.93, 0.32)))
	add(b, "silver", ShapeKit.box(Vector3(0.72, 0.1, 0.5)), xf(Vector3(0, 0.74, -0.45), Vector3(8, 0, 0)))
	for sx in [-1.0, 1.0]:
		# Side pontoons along the rear wheel, with soot vent slats.
		add(b, "silver", ShapeKit.capsule(0.2, 1.35), xf(Vector3(sx * 0.6, 0.45, 0.55), Vector3(90, 0, 0), Vector3(1, 1, 0.85)))
		for i in 3:
			add(b, "dark", ShapeKit.box(Vector3(0.02, 0.05, 0.3)), xf(Vector3(sx * 0.79, 0.4 + i * 0.07, 0.55)))
		add(b, "dark", ShapeKit.cyl(0.07, 0.08, 0.3, 8), xf(Vector3(sx * 0.6, 0.45, 1.3), Vector3(90, 0, 0)))
		_grooves(b, Vector3(sx * 0.52, 0.7, 0.3), 1.2, sx)
		_badge(b, Vector3(sx * 0.425, 1.0, 0.95), sx, 1.2)
		# Tall prow blades, leaning forward.
		add(b, "silver", ShapeKit.box(Vector3(0.07, 0.78, 0.5)), xf(Vector3(sx * 0.2, 0.92, -0.62), Vector3(-26, 0, 0)))
		add(b, "silver", ShapeKit.box(Vector3(0.07, 0.2, 0.62)), xf(Vector3(sx * 0.2, 0.55, -0.4), Vector3(4, 0, 0)))
	add(b, "glass", ShapeKit.box(Vector3(0.36, 0.3, 0.04)), xf(Vector3(0, 1.17, -0.66), Vector3(-38, 0, 0)))
	add(b, "dark", ShapeKit.box(Vector3(0.44, 0.05, 0.1)), xf(Vector3(0, 1.3, -0.74), Vector3(-38, 0, 0)))
	add(b, "lamp", ShapeKit.box(Vector3(0.22, 0.05, 0.03)), xf(Vector3(0, 0.82, -0.86)))
	add(b, "amber", ShapeKit.box(Vector3(0.05, 0.03, 0.02)), xf(Vector3(0, 1.21, 1.26)))
	add(b, "dark", ShapeKit.cyl(0.03, 0.03, 0.86, 6), xf(Vector3(0, 1.02, -0.38), Vector3(0, 0, 90)))
	# Front: exposed wheel, soot forks, a floating silver guard blade.
	steer_node = _node(b, "Steer", Vector3(0, 0.95, -0.95))
	for sx in [-1.0, 1.0]:
		add(steer_node, "dark", ShapeKit.cyl(0.035, 0.04, 0.72, 8), xf(Vector3(sx * 0.16, -0.3, -0.16), Vector3(-24, 0, 0)))
	add(steer_node, "silver", ShapeKit.box(Vector3(0.3, 0.04, 0.72)), xf(Vector3(0, 0.02, -0.26), Vector3(-6, 0, 0)))
	_wheel(steer_node, "wheel_front", Vector3(0, -0.53, -0.3), 0.42, 0.24, false, 0.26)
	_wheel(b, "wheel_rear", Vector3(0, 0.46, 1.05), 0.46, 0.34, false, 0.3)
	_seat = _socket(lean_node, "seat", _v(def.get("seat", [0, 0.95, 0.35])))


# --- 02 Sparrow: compact, springy, knobby -----------------------------------------------------------
## Silhouette: a short rounded bean frame, a black saddle, tall exposed twin
## forks with silver collars, a rounded-square black headlamp, oversized
## knobby black wheels and a visible rear spring.
func _sparrow() -> void:
	body = _node(lean_node, "Body", Vector3.ZERO)
	var b := body
	add(b, "silver", ShapeKit.capsule(0.21, 0.95), xf(Vector3(0, 0.72, 0.08), Vector3(80, 0, 0), Vector3(1.05, 1, 0.9)))
	add(b, "silver", ShapeKit.sphere(0.22, 12), xf(Vector3(0, 0.8, -0.3), Vector3.ZERO, Vector3(1, 0.85, 1.1)))
	add(b, "dark", ShapeKit.capsule(0.12, 0.6), xf(Vector3(0, 0.93, 0.25), Vector3(84, 0, 0), Vector3(1.2, 1, 0.55)))
	add(b, "dark", ShapeKit.box(Vector3(0.24, 0.06, 0.55)), xf(Vector3(0, 0.46, 0.0), Vector3(-6, 0, 0)))
	add(b, "dark", ShapeKit.box(Vector3(0.08, 0.08, 0.62)), xf(Vector3(0, 0.5, 0.42), Vector3(-18, 0, 0)))
	# Rear spring: soot damper with silver coils.
	add(b, "dark", ShapeKit.cyl(0.03, 0.03, 0.42, 6), xf(Vector3(0, 0.62, 0.42), Vector3(-35, 0, 0)))
	for i in 4:
		add(b, "silver", ShapeKit.torus(0.035, 0.055), xf(Vector3(0, 0.55 + i * 0.05, 0.37 + i * 0.035), Vector3(-35, 0, 0)))
	add(b, "silver", ShapeKit.box(Vector3(0.3, 0.03, 0.26)), xf(Vector3(0, 0.98, 0.62)))
	for sx in [-1.0, 1.0]:
		add(b, "silver", ShapeKit.box(Vector3(0.02, 0.1, 0.02)), xf(Vector3(sx * 0.13, 0.93, 0.62)))
		_badge(b, Vector3(sx * 0.22, 0.72, 0.1), sx, 0.9)
		_grooves(b, Vector3(sx * 0.2, 0.82, 0.2), 0.34, sx)
	add(b, "amber", ShapeKit.box(Vector3(0.04, 0.025, 0.02)), xf(Vector3(0, 0.99, 0.76)))
	steer_node = _node(b, "Steer", Vector3(0, 1.1, -0.5))
	for sx in [-1.0, 1.0]:
		add(steer_node, "dark", ShapeKit.cyl(0.042, 0.042, 1.02, 8), xf(Vector3(sx * 0.12, -0.36, -0.1), Vector3(-12, 0, 0)))
		add(steer_node, "silver", ShapeKit.cyl(0.058, 0.058, 0.14, 8), xf(Vector3(sx * 0.12, -0.02, -0.03), Vector3(-12, 0, 0)))
		add(steer_node, "dark", ShapeKit.cyl(0.035, 0.035, 0.12, 6), xf(Vector3(sx * 0.33, 0.2, 0.05), Vector3(0, 0, 90)))
	add(steer_node, "dark", ShapeKit.cyl(0.022, 0.022, 0.6, 6), xf(Vector3(0, 0.2, 0.05), Vector3(0, 0, 90)))
	add(steer_node, "silver", ShapeKit.box(Vector3(0.22, 0.2, 0.1)), xf(Vector3(0, -0.06, -0.14)))
	add(steer_node, "glass", ShapeKit.box(Vector3(0.18, 0.16, 0.02)), xf(Vector3(0, -0.06, -0.195)))
	add(steer_node, "lamp", ShapeKit.box(Vector3(0.08, 0.06, 0.01)), xf(Vector3(0, -0.06, -0.207)))
	_wheel(steer_node, "wheel_front", Vector3(0, -0.74, -0.22), 0.36, 0.22, true, 0.17)
	_wheel(b, "wheel_rear", Vector3(0, 0.37, 0.68), 0.37, 0.24, true, 0.17)
	_seat = _socket(lean_node, "seat", _v(def.get("seat", [0, 0.9, 0.2])))


# --- 03 Bellhull: upright amphibious capsule -----------------------------------------------------------
## Silhouette: an upright egg of worn silver on ONE big black wheel, a wide
## black window lens, an integrated soot chin with twin short barrels, a mast,
## side outrigger feet. In water the wheel folds up into the hull, float
## collars swell out and a stern propeller ring shows.
func _bellhull() -> void:
	body = _node(lean_node, "Body", Vector3.ZERO)
	var b := body
	add(b, "silver", ShapeKit.sphere(0.78, 16), xf(Vector3(0, 1.22, 0), Vector3.ZERO, Vector3(1.0, 1.32, 0.95)))
	add(b, "dark", ShapeKit.torus(0.72, 0.8), xf(Vector3(0, 1.86, 0), Vector3.ZERO, Vector3(0.78, 1, 0.74)))
	add(b, "dark", ShapeKit.torus(0.76, 0.81), xf(Vector3(0, 0.95, 0), Vector3.ZERO, Vector3(1.0, 1.4, 0.96)))
	add(b, "glass", ShapeKit.sphere(0.5, 14), xf(Vector3(0, 1.45, -0.56), Vector3.ZERO, Vector3(1.15, 0.5, 0.42)))
	add(b, "dark", ShapeKit.torus(0.5, 0.58), xf(Vector3(0, 1.45, -0.55), Vector3(90, 0, 0), Vector3(1.12, 1, 0.5)))
	# Chin weapon pod: soot housing, two short barrels (integrated, not a turret).
	add(b, "dark", ShapeKit.capsule(0.13, 0.72), xf(Vector3(0, 1.1, -0.66), Vector3(0, 0, 90)))
	for sx in [-1.0, 1.0]:
		add(b, "dark", ShapeKit.cyl(0.045, 0.05, 0.34, 8), xf(Vector3(sx * 0.18, 1.08, -0.86), Vector3(90, 0, 0)))
		_muzzles.append(_socket(b, "muzzle_%d" % _muzzles.size(), Vector3(sx * 0.18, 1.08, -1.08)))
		_badge(b, Vector3(sx * 0.77, 1.3, 0.05), sx, 1.3)
		_grooves(b, Vector3(sx * 0.76, 1.62, 0.0), 0.4, sx)
	add(b, "dark", ShapeKit.cyl(0.018, 0.022, 0.8, 5), xf(Vector3(-0.28, 2.28, 0.25)))
	add(b, "silver", ShapeKit.sphere(0.035, 6), xf(Vector3(-0.28, 2.69, 0.25)))
	add(b, "amber", ShapeKit.sphere(0.03, 6), xf(Vector3(0.3, 1.9, -0.52)))
	add(b, "lamp", ShapeKit.box(Vector3(0.3, 0.04, 0.02)), xf(Vector3(0, 1.72, -0.66), Vector3(-30, 0, 0)))
	# Wheel assembly (retracts): slot fairings + the big wheel.
	_retract = _node(b, "WheelAssembly", Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		add(_retract, "dark", ShapeKit.box(Vector3(0.08, 0.5, 0.9)), xf(Vector3(sx * 0.24, 0.62, 0)))
	_wheel(_retract, "wheel_main", Vector3(0, 0.55, 0), 0.55, 0.32, false, 0.3)
	# Outrigger feet with small black wheels (fold away in water).
	for sx in [-1.0, 1.0]:
		var o := _node(b, "outrigger", Vector3(sx * 0.62, 0.6, 0.32))
		add(o, "dark", ShapeKit.box(Vector3(0.06, 0.5, 0.08)), xf(Vector3(0, -0.22, 0), Vector3(0, 0, sx * -18)))
		_wheel(o, "wheel_side", Vector3(sx * 0.08, -0.44, 0), 0.16, 0.08, false, 0.08)
		_outriggers.append(o)
	# Water gear (hidden on land).
	_collar = _node(b, "FloatCollar", Vector3(0, 0.82, 0))
	add(_collar, "rubber", ShapeKit.torus(0.78, 1.0), xf(Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.6, 0.96)))
	for i in 6:
		var a := TAU * i / 6.0
		add(_collar, "silver", ShapeKit.box(Vector3(0.06, 0.14, 0.12)), xf(Vector3(cos(a) * 0.98, 0, sin(a) * 0.94), Vector3(0, -rad_to_deg(a), 0)))
	_collar.scale = Vector3.ONE * 0.01
	_collar.visible = false
	_prop = _node(b, "Propeller", Vector3(0, 0.5, 0.72))
	add(_prop, "dark", ShapeKit.torus(0.16, 0.22), xf(Vector3.ZERO, Vector3(90, 0, 0)))
	for i in 3:
		add(_prop, "dark", ShapeKit.box(Vector3(0.28, 0.05, 0.02)), xf(Vector3.ZERO, Vector3(0, 0, i * 60.0)))
	_prop.visible = false
	_seat = _socket(lean_node, "seat", _v(def.get("seat", [0, 0.9, 0.0])))


# --- Interface --------------------------------------------------------------------------------------
func seat() -> Node3D:
	return _seat


func muzzles() -> Array[Node3D]:
	return _muzzles


## speed m/s (signed), steer -1..1, lean target radians.
func update_motion(speed: float, steer: float, lean_target: float, grounded: bool, delta: float) -> void:
	for i in wheels.size():
		if i < wheel_radius.size():
			wheels[i].rotation.x -= speed / maxf(wheel_radius[i], 0.1) * delta
	if steer_node:
		steer_node.rotation.y = lerpf(steer_node.rotation.y, -steer * 0.45, minf(delta * 10.0, 1.0))
	_lean = lerpf(_lean, lean_target if grounded else lean_target * 0.4, minf(delta * 6.0, 1.0))
	lean_node.rotation.z = _lean
	_recoil = move_toward(_recoil, 0.0, delta * 3.0)
	var sus := float(def.get("handling", {}).get("suspension", 0.1))
	lean_node.position.y = -_charge * sus * 1.5 + sin(Time.get_ticks_msec() * 0.02) * 0.004 * absf(speed) / 10.0
	lean_node.rotation.x = _recoil * 0.06
	if _prop and _prop.visible:
		_prop.rotation.z += speed * delta * 2.0


func set_charge(t: float) -> void:
	_charge = clampf(t, 0.0, 1.0)


func recoil() -> void:
	_recoil = 1.0


## 0 = land (wheels down) .. 1 = water (wheels folded, collar out).
func set_water_blend(t: float) -> void:
	_water = clampf(t, 0.0, 1.0)
	var e := _water * _water * (3.0 - 2.0 * _water)
	if _retract:
		_retract.position.y = e * 0.55
		_retract.scale = Vector3.ONE * lerpf(1.0, 0.7, e)
	for o in _outriggers:
		o.rotation.z = signf(o.position.x) * e * 1.4
	if _collar:
		_collar.visible = e > 0.02
		_collar.scale = Vector3.ONE * maxf(e, 0.01)
	if _prop:
		_prop.visible = e > 0.6


func set_headlamp(on: bool) -> void:
	if on and _lamp == null and Quality.level >= 1:
		_lamp = SpotLight3D.new()
		_lamp.light_color = Color(1.0, 0.88, 0.7)
		_lamp.light_energy = 1.6
		_lamp.spot_range = 22.0
		_lamp.spot_angle = 32.0
		_lamp.shadow_enabled = false
		_lamp.distance_fade_enabled = true
		_lamp.distance_fade_begin = 40.0
		_lamp.distance_fade_length = 15.0
		_lamp.position = Vector3(0, 1.0 if String(def.get("class", "")) != "capsule" else 1.7, -1.0)
		_lamp.rotation_degrees = Vector3(-8, 0, 0)
		lean_node.add_child(_lamp)
	if _lamp:
		_lamp.visible = on


func set_flash(amount: float, color: Color = Color.WHITE) -> void:
	for g in _geoms:
		if is_instance_valid(g) and g.material_override is ShaderMaterial:
			g.set_instance_shader_parameter(&"flash", amount)
			g.set_instance_shader_parameter(&"flash_color", color)
