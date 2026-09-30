class_name Features
extends RefCounted
## World features that discoveries and quests can place (QuestSpawner kind
## "feature"): the forest's glowcaps and bellcaps, bramble walls, ribbon
## trail markers, fishing spots, air vents and storm buoys; the sea's
## currents, tide bars, surf, kelp, fog bells, spouts, whirlpools, mist
## banks and the dawn mirage.
##   {"kind": "feature", "feature": "<type>", "id": ..., "pos": [...], ...}

const TYPES := ["glowcap", "bellcap", "bramble", "ribbon", "fishing_spot", "air_vent", "storm_buoy", "storm_spire",
	"current", "tide_bar", "surf", "kelp", "fog_bell", "spout", "whirlpool", "mist_bank", "mirage"]


static func make(e: Dictionary) -> Node3D:
	var id := String(e.get("id", ""))
	match String(e.get("feature", "")):
		"glowcap":
			return Glowcap.create(id)
		"bellcap":
			return Bellcap.create(id, float(e.get("size", 1.3)))
		"bramble":
			var sz: Array = e.get("size", [3.2, 3.6, 1.2])
			return BrambleWall.create(id, Vector3(sz[0], sz[1], sz[2]))
		"ribbon":
			return _ribbon_post(id)
		"fishing_spot":
			return FishingSpot.create(id, String(e.get("waters", "lake")))
		"air_vent":
			return AirVent.new()
		"storm_buoy":
			return StormBuoy.create(id)
		"storm_spire":
			return StormBuoy.create(id, true)
		"current":
			var sc := SeaCurrent.create(float(e.get("length", 120.0)), float(e.get("width", 16.0)), float(e.get("strength", 3.5)))
			sc.tidal = bool(e.get("tidal", false))
			sc.glows = bool(e.get("glows", false))
			return sc
		"tide_bar":
			var tb: Array = e.get("size", [4.0, 1.0, 4.0])
			return TideBar.create(Vector3(tb[0], tb[1], tb[2]))
		"kelp":
			return Kelp.create(float(e.get("radius", 10.0)), int(e.get("count", 36)))
		"surf":
			var yaw := deg_to_rad(float(e.get("yaw", 0.0)))
			return Surf.create(float(e.get("radius", 5.0)), Vector3(-sin(yaw), 0, -cos(yaw)))
		"fog_bell":
			return FogBell.create(e)
		"spout":
			return Spout.create(float(e.get("radius", 2.6)), float(e.get("period", 7.0)))
		"whirlpool":
			return Whirlpool.create(float(e.get("radius", 18.0)), float(e.get("strength", 3.0)))
		"mist_bank":
			return MistBank.create(float(e.get("radius", 300.0)), float(e.get("edge", 70.0)), e.get("pockets", []))
		"mirage":
			return MirageShip.new()
	return null


## A trail marker: a stake with a red ribbon (hunters mark their paths).
static func _ribbon_post(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Ribbon_" + id
	var stake := MeshInstance3D.new()
	stake.mesh = ShapeKit.cyl(0.05, 0.07, 1.6, 5)
	stake.position.y = 0.8
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.45, 0.33, 0.22)
	stake.material_override = sm
	n.add_child(stake)
	var rib := MeshInstance3D.new()
	rib.mesh = ShapeKit.box(Vector3(0.05, 0.7, 0.18))
	rib.position = Vector3(0.08, 1.2, 0)
	rib.rotation.z = 0.25
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.85, 0.2, 0.15)
	rm.emission_enabled = true
	rm.emission = Color(0.5, 0.08, 0.05)
	rib.material_override = rm
	n.add_child(rib)
	return n
