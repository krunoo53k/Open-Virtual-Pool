extends Node

## Regression for the console errors: every scene that reads an action must
## register the shared defaults itself, even when opened without a shooter.

var _fails := 0


func _ready() -> void:
	add_child((load("res://scenes/camera_rig/camera_rig.tscn") as PackedScene).instantiate())
	add_child((load("res://scenes/input/cancel_input/cancel_input.tscn") as PackedScene).instantiate())
	add_child((load("res://scenes/match/view_hud/view_hud.tscn") as PackedScene).instantiate())
	for action in ["camera_toggle", "cancel", "debug_toggle", "dump_shot_log",
			"cue_draw", "cue_raise", "english_hold", "fine_trim"]:
		_check(InputMap.has_action(action), action + " is registered")
	print("input actions: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fails += 1
		printerr("  FAIL: ", note)
