class_name RewardPopup
extends Control
## Black-20 % card that slides in on the left when anything pays out (quest,
## bounty, challenge, discovery, encounter): one line per reward. Queued so
## back-to-back rewards never overlap; tiny item pickups stay in the feed.

var _queue: Array = []
var _lines := PackedStringArray()
var _heading := ""
var _t := 0.0
const SHOW := 3.6


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(380, 60)
	size = custom_minimum_size
	visible = false
	EventBus.rewards_granted.connect(_on_rewards)


func _on_rewards(source: String, r: Dictionary) -> void:
	var lines := Rewards.describe(r)
	if lines.is_empty():
		return
	var heading := "REWARD_HEADING"
	if source.begins_with("quest:"):
		heading = "QUEST_COMPLETED" if not source.ends_with(":bonus") else "REWARD_BONUS"
	elif source.begins_with("enc:"):
		heading = "ENC_SUCCESS"
	_queue.append([tr(heading), lines])
	Audio.play_ui(&"jade" if r.has("jade") else &"coin", -6.0)


func _process(delta: float) -> void:
	if _t <= 0.0:
		if _queue.is_empty():
			visible = false
			return
		var next: Array = _queue.pop_front()
		_heading = next[0]
		_lines = next[1]
		_t = SHOW
		size.y = 52 + _lines.size() * 30
	_t -= delta
	visible = true
	queue_redraw()


func _draw() -> void:
	var slide := clampf(minf(SHOW - _t, _t) * 4.0, 0.0, 1.0)
	var off := (1.0 - slide) * -size.x
	var a := slide
	var r := Rect2(Vector2(off, 0), size)
	draw_rect(r, Color(HudArt.SHADE, HudArt.SHADE.a * a))
	var tf := UITheme.title_font()
	var f := UITheme.font()
	HudArt.text(self, tf, r.position + Vector2(22, 34), _heading, UITheme.fs(22), a, HudArt.CELESTE, size.x - 30)
	for i in _lines.size():
		HudArt.text(self, f, r.position + Vector2(22, 66 + i * 30), _lines[i], UITheme.fs(19), a, HudArt.WHITE, size.x - 30)
