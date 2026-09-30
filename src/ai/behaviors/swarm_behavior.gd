class_name SwarmBehavior
extends AIBehavior
## Packs circle the target and strike one at a time: never a blob that
## hits all at once, always one diving in while the others wheel around.

static var _token: Dictionary = {}   # group -> [creature id, until msec]
var _angle := 0.0


func _init(brain: AIBrain) -> void:
	super(brain)
	_angle = float(c.get_instance_id() % 628) / 100.0


func pre_tick(delta: float) -> StringName:
	if c.group_id == "":
		return &""
	_angle += delta * 0.9
	var id := b.current.id()
	var now := Time.get_ticks_msec()
	var tok: Array = _token.get(c.group_id, [0, 0])
	var mine := int(tok[0]) == c.get_instance_id()
	if id == &"attack":
		_token[c.group_id] = [c.get_instance_id(), now + 2500]
	var free := now > int(tok[1]) or mine
	b.attack_blocked = not free
	b.chase_offset = Vector3(cos(_angle), 0, sin(_angle)) * (4.5 if not free else 0.0)
	return &""
