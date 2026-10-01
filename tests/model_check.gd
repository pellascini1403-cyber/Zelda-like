extends Node
## Validates a character model against the pipeline conventions
## (docs/CHARACTER_PIPELINE.md) before wiring it into data/entities.json.
## Run: godot --headless -- --check-model res://assets/models/hero.glb [ENTITY_ID]
## Exit code 0 = no errors (warnings are advisory).


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--check-model")
	var path := args[i + 1] if i >= 0 and args.size() > i + 1 else ""
	var id := StringName(args[i + 2]) if i >= 0 and args.size() > i + 2 else &"PLAYER"
	if path == "--fixture":
		path = load("res://tests/character_fixture.gd").save()
	if path == "" or not ResourceLoader.exists(path):
		print("model not found: '%s'" % path)
		get_tree().quit(2)
		return
	var model: Node3D = (load(path) as PackedScene).instantiate()
	var e: EntityType = DB.entities.get(id)
	var rep := CharacterModel.analyze(model, e)
	print("==== MODEL CHECK %s (as %s) ====" % [path, id])
	print("height %.2f m | %d bones | %d triangles | materials %s" % [rep.height, rep.bones, rep.tris, rep.materials])
	print("clips: %s" % ", ".join(rep.clips))
	print("variant meshes: %s" % ", ".join(rep.groups.keys()))
	print("spring bones: %s" % ", ".join(rep.springs))
	if e:
		var mapped := []
		for l in EntityVisual.LOGICAL:
			var clip: String = e.anim_map.get(String(l), String(l))
			if clip in rep.clips:
				mapped.append(String(l))
		print("logical states with a direct clip: %d/%d (the rest use FALLBACK)" % [mapped.size(), EntityVisual.LOGICAL.size()])
	for w in rep.warnings:
		print("WARN  ", w)
	for err in rep.errors:
		print("ERROR ", err)
	print("==== %d errors, %d warnings ====" % [rep.errors.size(), rep.warnings.size()])
	model.free()
	get_tree().quit(1 if rep.errors.size() > 0 else 0)
