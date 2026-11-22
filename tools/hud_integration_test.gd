extends Node3D

## Integration acceptance for #9: the real Match composer instances the real
## Hud. Only the adapter double scripts the shots; TurnFlow, EightBallRules and
## every HUD leaf are real. Exit code = number of failed assertions.

var _fails := 0

func _ready() -> void:
	$Match/ShotPlayback.time_scale = 1000.0
	var turn: TurnStatus = $Match/Hud/TurnStatus
	var foul: FoulBanner = $Match/Hud/FoulBanner
	var picker: CalledPocketPicker = $Match/Hud/CalledPocketPicker
	_check(turn.turn_text() == "player 1 to shoot" and not picker.visible, "initial turn and picker")
	_script(false, _break_events())
	await _play()
	_check(turn.turn_text() == "player 2 to shoot", "a legal break passes the turn")
	_check(turn.remaining_text() == "remaining: 15", "the break potted nothing")
	_check(foul.reason_text() == "", "a clean break leaves no foul reason")
	_script(false, [_ev("ball-ball", 0, 9, 0.2), _ev("pocket-drop", 9, 0, 1.0)])
	await _play()
	_check(turn.group_text(1) == "solids" and turn.group_text(2) == "stripes", "open pot assigns groups")
	_check(turn.remaining_text() == "remaining: 14", "the pot leaves the rack")
	var wide: Array[ShotEvent] = [_ev("ball-ball", 0, 10, 0.2)]
	for n in [10, 11, 12, 13, 14, 15]:
		wide.append(_ev("pocket-drop", n, 0, 1.0))
	_script(false, wide)
	await _play()
	_check(picker.visible, "picker visible when P2 is on the 8")
	await _press("ui_right")
	await _press("ui_accept")
	_script(true, [_ev("pocket-drop", 0, 0, 0.9)])
	var params := ShotParams.new()
	params.called_pocket = -1
	$Match/Shooter2.shot_committed.emit(params)
	_check(params.called_pocket == 1, "called pocket reaches the human shot params")
	await _wait()
	_check(foul.reason_text() == "scratch", "foul_committed reaches the HUD banner")
	_check(turn.turn_text() == "player 1 to shoot", "a scratch passes the turn")
	_check(not picker.visible, "picker hidden once the shooter is no longer on the 8")
	_script(false, [_ev("ball-ball", 0, 1, 0.2), _ev("pocket-drop", 1, 0, 1.0)])
	await _play()
	_check(foul.reason_text() == "", "a clean shot clears the foul banner")
	_check(turn.turn_text() == "player 1 to shoot", "an own-group pot keeps the turn")
	_check_pause()
	print("hud integration: ", _fails, " failed assertions")
	get_tree().quit(_fails)

func _check_pause() -> void:
	$Match/HudWiring/CancelInput.cancel_requested.emit()
	_check($Match/Hud/PauseMenu.is_open() and get_tree().paused, "cancel opens the real pause menu")
	($Match/Hud/PauseMenu/Choices/Resume as Button).pressed.emit()
	_check(not $Match/Hud/PauseMenu.is_open() and not get_tree().paused, "resume closes it and unpauses")

func _break_events() -> Array[ShotEvent]:
	var events: Array[ShotEvent] = [_ev("ball-ball", 0, 1, 0.3)]
	for n in [3, 5, 7, 9]:
		events.append(_ev("cushion", n, 2, 0.5))
	return events

func _script(foul: bool, events: Array[ShotEvent]) -> void:
	var outcome := ShotOutcome.new()
	outcome.phase = "settled"
	outcome.foul = foul
	$Match/Simulation.script_next(outcome, events)

func _play() -> void:
	$Match.take_shot(ShotParams.new())
	await _wait()


func _wait() -> void:
	var guard := 0
	while $Match.get_phase() != "AwaitingShot" and $Match.get_phase() != "GameOver":
		if $Match.get_phase() == "BallInHand":
			_place_cue()
		await get_tree().process_frame
		guard += 1
		if guard > 900:
			_fails += 1
			printerr("hud integration: flow stalled in ", $Match.get_phase())
			return

func _place_cue() -> void:
	# #8 made ball-in-hand wait for the player's spot: drive the same real
	# input scene the mouse uses, picking the first legal grid point.
	var layout: TableLayout = $Match/Simulation.layout
	for i in range(1, 10):
		for j in range(1, 5):
			var spot := Vector3(layout.length * i / 10.0, layout.ball_radius,
				-layout.width * j / 5.0)
			if CuePlacement.is_legal(spot, layout, $Match.rack) and $Match/BallInHandInput.place_at(spot):
				return
	_fails += 1
	printerr("hud integration: no legal ball-in-hand spot found")


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame

func _ev(kind: String, ball: int, other: int, time: float) -> ShotEvent:
	var event := ShotEvent.new()
	event.kind = kind
	event.ball = ball
	event.other = other
	event.time = time
	return event

func _check(ok: bool, note: String) -> void:
	if not ok:
		_fails += 1
		printerr("hud integration said no: ", note)
