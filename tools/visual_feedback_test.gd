extends Node3D

## Acceptance for #30: the live views receive the active shooter's typed
## state, the cue follows it, and the QoL toggles work. The real Match scene
## and adapter are used; only the leaf gestures are driven directly.

var _fails := 0


# lint-ignore: long-func (one harness drives the whole view feedback sequence in order)
func _ready() -> void:
	var game = $Match
	for _i in range(3):
		await get_tree().process_frame
	var shooter: HumanShooter = game.get_node("Shooter1")
	var cue: MeshInstance3D = game.get_node("AimView/CueStick/Shaft")
	var line: MeshInstance3D = game.get_node("AimView/AimPreview/GhostLine")
	var hud = game.get_node("ViewHud")
	var rig = game.get_node("CameraRig")
	game.get_node("ShotPlayback").time_scale = 100.0  # keep this harness quick
	_check(cue.visible, "cue is visible while aiming")
	_check(line.visible, "the adapter's aim line is visible")
	var before: Transform3D = cue.transform
	shooter.get_aim_leaf().aim_dragged(Vector2(40.0, 0.0), false)
	await get_tree().process_frame
	_check(cue.transform != before, "the cue follows the aim gesture")
	_check(game.get_node("AimView").get_state() != null, "typed view state reached the aim view")

	var pose_before: Transform3D = cue.transform
	shooter.get_stroke_leaf().start_stroke()
	shooter.get_stroke_leaf().draw_motion(Vector2(0.0, 120.0))
	await get_tree().process_frame
	_check(AimStateReader.read(shooter).pull_m > 0.0, "the draw reaches the view state")
	_check(cue.transform != pose_before, "the cue pulls back with the draw")
	shooter.get_english_leaf().tip_dragged(Vector2(20.0, 0.0), false)
	await get_tree().process_frame
	_check(game.get_node("AimView/CueStick/TipMarker").visible, "the tip marker shows english")
	shooter.get_stroke_leaf().draw_motion(Vector2(0.0, -120.0))
	await get_tree().process_frame
	_check(hud.get_node("PowerBar").value > 0.0, "the power bar shows the stroke speed")
	var guard := 0
	while game.get_phase() == "Striking" and guard < 60:
		await get_tree().process_frame
		guard += 1
	_check(not game.get_node("AimView/CueStick").visible, "the cue hides once the shot is away")
	var settle := 0
	while game.get_phase() != "AwaitingShot" and settle < 300:
		if game.get_phase() == "BallInHand":
			PlacementHelper.place_cue(game.get_node("BallInHandInput"),
				game.get_node("Simulation").layout, game.rack)
		await get_tree().process_frame
		settle += 1
	_check(game.get_phase() == "AwaitingShot", "the flow settles back to aiming")
	_check(AimStateReader.read(shooter).pull_m == 0.0,
		"the cue returns to the same spot against the ball")

	_check(InputMap.has_action("debug_toggle") and InputMap.has_action("camera_toggle"),
		"the view toggles are bound to InputMap actions")
	hud.toggle_debug()
	_check(hud.is_debug_open(), "the debug panel opens")
	var camera_before = rig.get_active_camera()
	rig.toggle_view()
	_check(rig.get_active_camera() != camera_before, "the camera toggles between eyes")
	_check(game.get_node("BallInHandInput").camera == rig.get_active_camera(),
		"ball-in-hand follows the active camera")
	print("visual feedback: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fails += 1
		printerr("  FAIL: ", note)
