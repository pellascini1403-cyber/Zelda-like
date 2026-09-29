extends Node
## Entry point. Autoloads are ready here; decide where to go.
## Command line (after `--`):
##   --new-game / --continue   skip the title screen
##   --unit                    run unit / data tests (debug builds)
##   --smoke                   run the automated gameplay smoke test (debug builds)
##   --tour <dir>              render reference screenshots (debug builds)


func _ready() -> void:
	Game.state = Game.State.MENU
	var args := OS.get_cmdline_user_args()
	if OS.is_debug_build():
		for pair in [["--unit", "res://tests/unit_tests.gd"], ["--smoke", "res://tests/smoke_test.gd"], ["--tour", "res://tests/screenshot_tour.gd"]]:
			if pair[0] in args:
				var test: Node = load(pair[1]).new()
				get_tree().root.add_child.call_deferred(test)
				return
	if "--new-game" in args:
		Game.start_game.call_deferred(false)
	elif "--continue" in args:
		Game.start_game.call_deferred(true)
	else:
		get_tree().change_scene_to_file.call_deferred(Game.MENU_SCENE)
