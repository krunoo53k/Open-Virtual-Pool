extends Node3D

## Headless acceptance for the hold-M ball-in-hand: a preview moves the cue
## visibly but locks nothing, the aim is not turned by the holding drag, and
## the last spot is the one committed by the shot. Exit code is the number of
## failed assertions.

var _fails := 0
var _placed_emits := 0


func _ready() -> void:
	$Match/ShotPlayback.time_scale = 1000.0
	$Match/BallInHandInput.cue_ball_placed.connect(_on_placed)
	var opening: Array[ShotEvent] = [_ev("ball-ball", 0, 1, 0.3)]
	for n in [3, 5, 7, 9]:
		opening.append(_ev("cushion", n, 2, 0.5))
	$Match/Simulation.script_next(_outcome(false), opening)
	$Match.take_shot(ShotParams.new())
	await _settle()
	var scratch := _outcome(true)
	scratch.pocketed.append(0)
	var events: Array[ShotEvent] = [_ev("pocket-drop", 0, 0, 0.9)]
	$Match/Simulation.script_next(scratch, events)
	$Match.take_shot(ShotParams.new())
	await _settle()
	await _run()


func _run() -> void:
	var game = $Match
	var flow := $Match/MatchFlow as MatchFlow
	var input := $Match/BallInHandInput as BallInHandInput
	var layout: TableLayout = $Match/Simulation.layout
	_check(game.get_phase() == "BallInHand", "the foul grants ball-in-hand")
	_check(input.is_active(), "the hold gesture is live")
	_check($Match/Shooter1.is_processing_unhandled_input(), "the player can aim with the cue in hand")

	var aim: AimInput = $Match/Shooter1.get_aim_leaf()
	var before := aim.get_level_aim_deg()
	Input.action_press("ball_in_hand")
	await _relative(Vector2(40.0, 0.0))
	_check(aim.get_level_aim_deg() == before, "holding M does not turn the shot line")
	Input.action_release("ball_in_hand")
	await _relative(Vector2(40.0, 0.0))
	_check(aim.get_level_aim_deg() != before, "the drag turns the line once M is released")

	var first := PlacementHelper.clean_spot(layout, game.rack)
	flow.preview_cue_placement(first)
	await get_tree().process_frame
	_check(game.rack.positions[0].distance_to(first) < 0.0001, "a preview moves the model cue")
	_check($Match/BallRack.get_child(0).position.distance_to(first) < 0.0001, "a preview moves the visible cue")
	_check(game.get_phase() == "BallInHand" and input.is_active(), "a preview leaves the cue in hand")
	_check(_placed_emits == 0, "a preview locks no placement in")

	var second := _other_spot(layout, game.rack, first)
	flow.preview_cue_placement(second)
	await get_tree().process_frame
	_check(game.rack.positions[0].distance_to(second) < 0.0001, "the cue can be moved again before the shot")
	_check(_placed_emits == 0, "moving again still locks nothing in")

	var clean: Array[ShotEvent] = [_ev("ball-ball", 0, 1, 0.3), _ev("cushion", 1, 2, 0.5)]
	$Match/Simulation.script_next(_outcome(false), clean)
	$Match.take_shot(ShotParams.new())
	await _settle()
	_check(not game.get_state().ball_in_hand, "the shot commits the placement")
	_check(not input.is_active(), "the shot releases the gesture")
	# The core may roll the cue a little during the stroke; it must still have
	# started from the last spot previewed, not from the head spot.
	_check(game.rack.positions[0].distance_to(second) < 0.2, "the last previewed spot is the one shot")
	_check(game.get_phase() == "AwaitingShot", "the turn resumes after the roll")
	print("hold ball-in-hand: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _other_spot(layout: TableLayout, rack: RackState, first: Vector3) -> Vector3:
	for i in range(12):
		for j in range(6):
			var p := Vector3(layout.length * (0.92 - 0.06 * i), layout.ball_radius,
				-layout.width * (0.12 + 0.14 * j))
			if p.distance_to(first) > 0.2 and CuePlacement.is_legal(p, layout, rack):
				return p
	return first


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


func _settle() -> void:
	var guard := 0
	while not ["AwaitingShot", "BallInHand", "GameOver"].has($Match.get_phase()):
		await get_tree().process_frame
		guard += 1
		if guard > 900:
			_check(false, "flow stalled in " + $Match.get_phase())
			return


func _on_placed(_position: Vector3) -> void:
	_placed_emits += 1


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fails += 1
		printerr("  FAIL: ", note)
