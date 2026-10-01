class_name FishingSpot
extends Interactable
## Where fish gather (rings on the water, now and then a jump). One button,
## three beats: cast (use), wait for the bobber to dip, pull (use again)
## inside a short window. What bites depends on the waters (lake, sea,
## river), the hour, the weather — data/fishing.json. A spot rests after a
## few catches. Needs a fishing rod. The same spot works for the lake, the
## coast and the sea.

enum Phase { IDLE, WAITING, BITE }

const CATCHES_BEFORE_REST := 3
const REST_HOURS := 8.0

var feature_id := ""
var waters := "lake"
var phase := Phase.IDLE
var _t := 0.0
var _bite_at := 0.0
var _catches := 0
var _rings: MeshInstance3D
var _bobber: MeshInstance3D
var _jump := 3.0

static var _ring_mat: StandardMaterial3D


static func create(id: String, water_kind: String = "lake") -> FishingSpot:
	var f := FishingSpot.new()
	f.feature_id = id
	f.waters = water_kind
	f.radius = 3.6
	return f


func _ready() -> void:
	super._ready()
	add_to_group(&"fishing_spots")
	if _ring_mat == null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.albedo_color = Color(0.9, 0.97, 1.0, 0.55)
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rings = MeshInstance3D.new()
	_rings.mesh = ShapeKit.torus(1.1, 1.25)
	_rings.material_override = _ring_mat
	_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rings)
	_bobber = MeshInstance3D.new()
	_bobber.mesh = ShapeKit.sphere(0.12, 8)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.9, 0.2, 0.15)
	_bobber.material_override = bm
	_bobber.visible = false
	add_child(_bobber)
	visible = not resting()


func resting() -> bool:
	return WorldState.is_harvested(feature_id)


func _process(delta: float) -> void:
	if resting():
		visible = false
		return
	visible = true
	var k := fmod(Time.get_ticks_msec() * 0.0006, 1.0)
	_rings.scale = Vector3.ONE * (0.5 + k * 1.3)
	_rings.transparency = k
	_jump -= delta
	if _jump <= 0.0 and phase == Phase.IDLE:
		_jump = randf_range(4.0, 9.0)
		if Game.player and Game.player.global_position.distance_to(global_position) < 40.0:
			Effects.splash(self, global_position + Vector3(randf_range(-1, 1), 0.1, randf_range(-1, 1)))
	match phase:
		Phase.WAITING:
			_t += delta
			_bobber.position.y = 0.05 + sin(_t * 3.0) * 0.03
			if _t >= _bite_at:
				phase = Phase.BITE
				_t = 0.0
				_bobber.position.y = -0.15
				Effects.splash(self, global_position + Vector3.UP * 0.1)
				Audio.play_at(&"splash", global_position, 2.0, 0.2)
				EventBus.toast.emit(tr("FISH_BITE"))
				InputRouter.vibrate(60, 0.7)
		Phase.BITE:
			_t += delta
			if _t > bite_window():
				phase = Phase.IDLE
				_bobber.visible = false
				EventBus.toast.emit(tr("FISH_ESCAPED"))


## Rain makes fish bold (they bite sooner); a still, bright noon makes
## them shy.
func wait_time() -> float:
	var base := randf_range(2.5, 6.0)
	if Weather.rain > 0.3:
		base *= 0.6
	if Clock.hour > 11.0 and Clock.hour < 15.0 and Weather.cloud_cover < 0.3:
		base *= 1.4
	return base


func bite_window() -> float:
	return 1.1


func prompt_key() -> String:
	match phase:
		Phase.WAITING:
			return "PROMPT_FISH_WAIT"
		Phase.BITE:
			return "PROMPT_FISH_PULL"
	return "PROMPT_FISH"


func can_interact() -> bool:
	return not resting()


func interact(player: Player) -> void:
	match phase:
		Phase.IDLE:
			if PlayerData.inventory.count_of(&"fishing_rod") <= 0:
				EventBus.toast.emit(tr("HINT_NEED_ROD"))
				return
			player.start_busy(&"interact", 0.6)
			player.visual.play_action(&"attack_1", 0.6)
			phase = Phase.WAITING
			_t = 0.0
			_bite_at = wait_time()
			_bobber.visible = true
			_bobber.position = Vector3(0, 0.05, 0)
			Audio.play_at(&"swing", player.global_position, -6.0)
		Phase.WAITING:
			# Pulled too early: the fish is spooked.
			phase = Phase.IDLE
			_bobber.visible = false
			EventBus.toast.emit(tr("FISH_TOO_SOON"))
		Phase.BITE:
			phase = Phase.IDLE
			_bobber.visible = false
			var fish := Fishing.roll(waters, randf())
			if fish == &"":
				EventBus.toast.emit(tr("FISH_ESCAPED"))
				return
			Fishing.land(fish)
			player.start_busy(&"interact", 0.5)
			player.visual.play_action(&"interact", 0.5)
			_catches += 1
			if _catches >= CATCHES_BEFORE_REST:
				_catches = 0
				WorldState.mark_harvested(feature_id, REST_HOURS)
