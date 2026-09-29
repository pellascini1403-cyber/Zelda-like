class_name QuestActor
extends CharacterBody3D
## A person (or cart) that quest encounters revolve around: someone to
## escort, protect, rescue, or a traveller in trouble. Uses the entity's
## usual EntityVisual (placeholder or final model), can be hurt by enemies
## (it sits on the props layer so enemy swings and slams reach it) and
## walks along paths. It never fights back.

signal died_signal(actor: QuestActor)
signal arrived

var type: EntityType
var visual: EntityVisual
var max_health := 100.0
var health := 100.0
var speed := 1.8
var path: Array[Vector3] = []
var walking := false
var cowering := false
var tied := false
var _collision: CollisionShape3D
var _facing := 0.0
var _hurt_t := 0.0
var _label: Label3D
var _settled := false
## Optional interaction (captive to free, lost person to talk to):
## {id, group, prompt, lines, speaker, untie, then_path: [Vector3], vanish}
var talk: Dictionary = {}


static func create(entity_id: StringName, hp: float = 100.0) -> QuestActor:
	var a := QuestActor.new()
	a.type = DB.entity(entity_id)
	a.max_health = hp
	a.health = hp
	return a


func _ready() -> void:
	add_to_group(&"quest_actors")
	collision_layer = 1 << 3
	collision_mask = 1
	_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = type.collider_radius if type else 0.35
	shape.height = maxf(type.collider_height if type else 1.7, shape.radius * 2.0)
	_collision.shape = shape
	_collision.position.y = shape.height * 0.5
	add_child(_collision)
	visual = EntityVisual.new()
	add_child(visual)
	if type:
		visual.setup(type)
		speed = type.walk_speed
	floor_snap_length = 0.6
	if not talk.is_empty():
		var it := ActorTalk.new()
		it.actor = self
		add_child(it)


## Context-button interaction on a quest actor: frees a captive, or simply
## talks. Emits quest_object_used(id, group) like any quest object.
class ActorTalk:
	extends Interactable
	var actor: QuestActor

	func _ready() -> void:
		radius = 1.6
		super._ready()

	func prompt_key() -> String:
		return String(actor.talk.get("prompt", "PROMPT_FREE" if actor.tied else "PROMPT_TALK"))

	func can_interact() -> bool:
		return not actor.is_dead() and not WorldState.flags.has("qo:" + String(actor.talk.get("id", "")))

	func interact(player: Player) -> void:
		var t: Dictionary = actor.talk
		var id := String(t.get("id", ""))
		player.start_busy(&"interact", 0.4)
		player.visual.play_action(&"interact", 0.4)
		if id != "":
			WorldState.flags["qo:" + id] = true
		actor.tied = false
		actor.cowering = false
		actor.face(player.global_position)
		var lines: Array = t.get("lines", [])
		if not lines.is_empty():
			EventBus.dialogue_requested.emit(String(t.get("speaker", actor.type.name_key if actor.type else "")), PackedStringArray(lines))
		Audio.play_at(&"pickup", actor.global_position, -4.0)
		EventBus.quest_object_used.emit(StringName(id), StringName(t.get("group", "")))
		var route: Array[Vector3] = []
		for q in t.get("then_path", []):
			route.append(q)
		if not route.is_empty():
			actor.follow(route)
			if t.get("vanish", true):
				actor.arrived.connect(actor.queue_free, CONNECT_ONE_SHOT)
		queue_free()


func is_dead() -> bool:
	return health <= 0.0


func take_damage(info: DamageInfo) -> void:
	# The player can never hurt the people they are helping.
	if is_dead() or info.source == Game.player:
		return
	health -= info.amount
	_hurt_t = 0.35
	visual.set_flash(1.0, Color(1.0, 0.4, 0.3))
	visual.play_action(&"hit", 0.35)
	Audio.play_at(&"npc_ouch", global_position, -4.0)
	if health <= 0.0:
		health = 0.0
		walking = false
		visual.play_action(&"die", 1.0)
		died_signal.emit(self)


func heal_full() -> void:
	health = max_health


## Floating one-word call ("Help!") above the head; "" hides it.
func shout(text_key: String) -> void:
	if text_key == "":
		if _label:
			_label.visible = false
		return
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.fixed_size = true
		_label.pixel_size = 0.0025
		_label.font_size = 40
		_label.outline_size = 10
		_label.modulate = UIArt.GOLD
		_label.font = UITheme.title_font()
		_label.position.y = (type.collider_height if type else 1.7) + 0.7
		add_child(_label)
	_label.text = tr(text_key)
	_label.visible = true


func follow(points: Array[Vector3]) -> void:
	path = points
	walking = not path.is_empty()


func _physics_process(delta: float) -> void:
	# Hold still until the ground under us has collision (streaming).
	if not _settled:
		var w := Game.world as GameWorld
		if w and w.streamer and not w.streamer.has_collision_at(global_position):
			return
		_settled = true
	if _hurt_t > 0.0:
		_hurt_t -= delta
		if _hurt_t <= 0.0:
			visual.set_flash(0.0)
	var move := Vector3.ZERO
	if walking and not is_dead() and not path.is_empty():
		var to := path[0] - global_position
		to.y = 0.0
		if to.length() < 1.2:
			path.remove_at(0)
			if path.is_empty():
				walking = false
				arrived.emit()
		else:
			move = to.normalized() * speed
			_facing = lerp_angle(_facing, atan2(-move.x, -move.z), minf(delta * 6.0, 1.0))
	velocity.x = move.x
	velocity.z = move.z
	velocity.y = -1.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	visual.rotation.y = _facing
	var state := &"idle"
	if cowering or tied:
		state = &"block"
	visual.set_locomotion(Vector2(velocity.x, velocity.z).length() / maxf(speed * 2.0, 0.1), &"walk" if move != Vector3.ZERO else state)


func face(point: Vector3) -> void:
	var to := point - global_position
	_facing = atan2(-to.x, -to.z)
