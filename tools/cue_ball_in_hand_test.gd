extends Node3D

# lint-ignore-file: use-input-map (the harness injects the real key events it tests)

## Headless acceptance for the cue-eye ball-in-hand scheme: a fixed-rate drag
## replaces the ray, rotation is locked while M is held and free when it is
## not, and the draw key locks the spot. Exit code is the number of failed
## assertions.

var _fails := 0


func _ready() -> void:
	$Match/ShotPlayback.time_scale = 1000.0
	var opening: Array[ShotEvent] = [_ev("ball-ball", 0, 1, 0.3)]
	for n in [3, 5, 7, 9]:
		opening.append(_ev("cushion", n, 2, 0.5))
	$Match/Simulation.script_next(_outcome(false), opening)
	$Match.take_shot(ShotParams.new())
	await _settle()
	var scratch := _outcome(true)
	scratch.pocketed.append(0)
	var drop: Array[ShotEvent] = [_ev("pocket-drop", 0, 0, 0.9)]
	$Match/Simulation.script_next(scratch, drop)
	# Fire this one through the real shooter: a direct take_shot leaves the
	# shooter's settling flag clear and hides the stuck-look regression.
	await _stroke()
	await _settle()
	await _run()


func _run() -> void:
	var game = $Match
	var input := $Match/BallInHandInput as BallInHandInput
	var camera := $Match/CameraRig/CueCamera as Camera3D
	$Match/CameraRig.toggle_view()
	_check($Match/CameraRig.is_cue_view(), "the cue eye is live")
	_check(input.camera == camera, "ball-in-hand uses the cue eye")

	var start: Vector3 = game.rack.get_position(0)
	var facing := camera.global_rotation
	Input.action_press("ball_in_hand")
	# Headless stretches synthetic motion by 30x; a small injection lands in
	# the same place as an ordinary short drag in a real window.
	await _relative(Vector2(1.5, 0.0))
	await _relative(Vector2(0.0, -1.5))
	var moved: Vector3 = game.rack.get_position(0)
	var delta := moved.distance_to(start)
	_check(delta > 0.05 and delta < 0.5, "a cue-eye drag moves the ball at a fixed, small rate")
	_check(camera.global_rotation.distance_to(facing) < 0.0001, "holding M locks the camera rotation")

	Input.action_release("ball_in_hand")
	facing = camera.global_rotation
	await _relative(Vector2(2.0, 0.0))
	_check(camera.global_rotation.distance_to(facing) > 0.001, "releasing M turns the camera around the ball")
	_check(game.rack.get_position(0).distance_to(moved) < 0.0001, "looking around does not move the ball")

	Input.action_press("ball_in_hand")
	facing = camera.global_rotation
	await _relative(Vector2(2.0, 0.0))
	_check(camera.global_rotation.distance_to(facing) < 0.0001, "pressing M again locks rotation")
	moved = game.rack.get_position(0)

	await _key(KEY_S, true)
	_check(not input.is_active(), "the draw key locks the spot")
	_check(game.rack.get_position(0).distance_to(moved) < 0.0001, "the locked spot is the last preview")
	await _key(KEY_S, false)
	await _key(KEY_ESCAPE, true)
	await _key(KEY_ESCAPE, false)
	await _relative(Vector2(3.0, 0.0))
	_check(game.rack.get_position(0).distance_to(moved) < 0.0001, "cancelling the stroke keeps the spot locked")
	print("cue ball-in-hand: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _outcome(foul: bool) -> ShotOutcome:
	var outcome := ShotOutcome.new()
	outcome.phase = "settled"
	outcome.foul = foul
	return outcome


func _ev(kind: String, ball: int, other: int, time: float) -> ShotEvent:
	var event := ShotEvent.new()
	event.kind = kind
	event.ball = ball
	event.other = other
	event.time = time
	return event


func _relative(relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	Input.parse_input_event(motion)
	await get_tree().process_frame
	await get_tree().process_frame


func _stroke() -> void:
	await _key(KEY_S, true)
	await _relative(Vector2(0.0, 200.0))
	await _relative(Vector2(0.0, -200.0))
	await _key(KEY_S, false)


func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _settle() -> void:
	var guard := 0
	while not ["AwaitingShot", "BallInHand", "GameOver"].has($Match.get_phase()):
		await get_tree().process_frame
		guard += 1
		if guard > 900:
			_check(false, "flow stalled in " + $Match.get_phase())
			return


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fails += 1
		printerr("  FAIL: ", note)
