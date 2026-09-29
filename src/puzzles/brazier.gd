class_name Brazier
extends StaticBody3D
## Stone brazier. Lit by any fire (fire weapons, burning props, spreading
## grass fire, explosions) or by striking flint on it (interact, costs one
## flint). Rain does not put a lit brazier out: it is sheltered.

var puzzle_id := ""
var lit := false
var _fire: FireSource
var _prompt: BrazierInteract


func _ready() -> void:
	collision_layer = 1 | (1 << 3)
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.55
	shape.height = 1.2
	cs.shape = shape
	cs.position.y = 0.6
	add_child(cs)
	var k := StructureKit.new(get_instance_id())
	StructureKit.prism_into(k.b, Vector3.ZERO, Vector3(0, 0.25, 0), 0.6, 0.55, 8, StructureKit.id(StructureKit.WHITE_STONE, 1.0))
	StructureKit.prism_into(k.b, Vector3(0, 0.25, 0), Vector3(0, 0.9, 0), 0.22, 0.2, 8, StructureKit.id(StructureKit.COOL_STONE, 1.0))
	StructureKit.prism_into(k.b, Vector3(0, 0.9, 0), Vector3(0, 1.2, 0), 0.35, 0.62, 8, StructureKit.id(StructureKit.GOLD * 0.7, StructureKit.GILT))
	var mi := MeshInstance3D.new()
	mi.mesh = k.b.commit()
	mi.material_override = WorldMaterials.get_mat(&"architecture")
	add_child(mi)
	_prompt = BrazierInteract.new()
	_prompt.brazier = self
	_prompt.position.y = 0.9
	add_child(_prompt)
	var g := PuzzleGroup.find(get_tree(), puzzle_id)
	if g:
		g.register(self)
	if g and g.is_solved():
		light(true)


func is_active() -> bool:
	return lit


## FireSource / fire hits call this.
func ignite() -> void:
	light(false)


func take_damage(info: DamageInfo) -> void:
	if info.element == &"fire":
		light(false)


func light(silent: bool) -> void:
	if lit:
		return
	lit = true
	_fire = FireSource.new()
	_fire.permanent = true
	_fire.spreads = false
	_fire.radius = 0.5
	add_child(_fire)
	_fire.position.y = 1.15
	if not silent:
		ElementFX.burst(self, global_position + Vector3.UP * 1.2, &"fire", 1.2)
	var g := PuzzleGroup.find(get_tree(), puzzle_id)
	if g:
		g.element_changed()


class BrazierInteract:
	extends Interactable
	var brazier: Brazier

	func _ready() -> void:
		radius = 1.3
		super._ready()

	func prompt_key() -> String:
		return "PROMPT_LIGHT"

	func can_interact() -> bool:
		return not brazier.lit and PlayerData.inventory.has(&"flint")

	func interact(_player: Player) -> void:
		PlayerData.inventory.remove(&"flint", 1)
		brazier.light(false)
