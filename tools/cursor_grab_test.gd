extends Node3D

## Headless check of the cursor hand-off: the leaf grabs only during play,
## and the match releases the pointer when the pause menu opens. Exit code is
## the number of failed assertions.

var _fails := 0


func _ready() -> void:
	var leaf := $Leaf as CursorGrab
	_check(not leaf.is_grabbed(), "the leaf starts with a free pointer")
	# Headless has no OS cursor, so assert the state the leaf drives rather
	# than DisplayServer's no-op mouse mode.
	leaf.set_phase("AwaitingShot")
	_check(leaf.is_grabbed(), "a play phase grabs the cursor")
	leaf.set_ui_open(true)
	_check(not leaf.is_grabbed(), "a menu frees the cursor")
	leaf.set_ui_open(false)
	_check(leaf.is_grabbed(), "closing the menu grabs it again")
	leaf.set_phase("GameOver")
	_check(not leaf.is_grabbed(), "game over frees the cursor")
	leaf.free()

	var pack := preload("res://scenes/match/match.tscn") as PackedScene
	var game = pack.instantiate()
	game.simulation_scene = preload("res://tools/scripted_simulation.tscn")
	add_child(game)
	var grab := $Match/CursorGrab as CursorGrab
	_check(game.get_phase() == "AwaitingShot" and grab.is_grabbed(), "the match grabs on entry")
	$Match/HudWiring/CancelInput.cancel_requested.emit()
	_check(not grab.is_grabbed(), "pausing frees the pointer")
	$Match/Hud.resume_requested.emit()
	_check(grab.is_grabbed(), "resuming grabs it again")
	print("cursor grab: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fail(note)


func _fail(note: String) -> void:
	_fails += 1
	printerr("  FAIL: ", note)
