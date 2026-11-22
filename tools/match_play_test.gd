extends Node3D

# lint-ignore-file: script-too-long (one harness drives a full game and asserts the scratch rack hand-off)

## Headless acceptance for #7. Drives the match's real public take_shot entry
## through a full legal game - break, open-table group, scratch and ball-in-hand,
## a called 8 - and asserts turn alternation, the six phases and the winner.
## The tools-only adapter double scripts the event stream; the turn flow,
## EightBallRules, the typed conversion and the rack bookkeeping are real.

var _fails := 0
var _turns: Array[int] = []
var _phases: Array[String] = []
var _winner := 0


func _ready() -> void:
	var game = $Match
	game.turn_changed.connect(_on_turn)
	game.match_finished.connect(_on_finished)
	$Match/TurnFlow.phase_entered.connect(_on_phase)
	$Match/ShotPlayback.time_scale = 1000.0  # finish each replay in one frame
	await _run_game()
	print("match play-test: ", _fails, " failed assertions; winner ", _winner)
	get_tree().quit(_fails)


func _run_game() -> void:
	var game = $Match
	_check(game.get_phase() == "AwaitingShot", "starts awaiting a shot")
	_check(game.get_current_player() == 1, "player 1 breaks")

	# hotseat: the inactive shooter's stroke is not listened to
	$Match/Shooter2.shot_committed.emit(ShotParams.new())
	_check(game.get_phase() == "AwaitingShot", "inactive shooter is ignored")

	# the real converter maps the core's indices into ball numbers
	var probe = $Match/Simulation.resolve(ShotParams.new(), game.rack)
	var typed := ShotEvents.from_core(probe.get_events(), game.rack)
	_check(typed.size() > 0, "raw core events convert to typed ShotEvents")

	# 1. a legal break: four rails, no pot, so the turn passes
	var opening: Array[ShotEvent] = [_ev("ball-ball", 0, 1, 0.3)]
	for n in [3, 5, 7, 9]:
		opening.append(_ev("cushion", n, 2, 0.5))
	_script(false, opening)
	await _play(-1)
	_check(game.get_current_player() == 2, "a legal break passes the turn")
	_check(not game.get_state().break_next, "the break flag clears")

	# 2. the open table assigns solids to the shooter who pots one
	_script(false, [_ev("ball-ball", 0, 2, 0.2), _ev("pocket-drop", 2, 0, 1.0)])
	await _play(-1)
	_check(game.get_state().solids_player == 2, "open-table pot assigns solids")
	_check(game.get_current_player() == 2, "an own-group pot keeps the turn")

	# 3. a scratch grants ball-in-hand to the incoming player
	var rack_before_scratch: int = game.rack.numbers.size()
	_script(true, [_ev("pocket-drop", 0, 0, 0.9)])
	await _play(-1)
	_check(game.get_current_player() == 1, "a scratch passes the turn")
	_check(game.get_state().ball_in_hand, "a scratch grants ball-in-hand")
	_check(_phases.has("BallInHand"), "the BallInHand phase was entered")
	# the cue is respotted, not dropped from the rack (the core reports it in
	# outcome.pocketed on a scratch, so after_shot has to keep number 0)
	_check(game.rack.numbers.has(0) and game.rack.numbers.size() == rack_before_scratch,
		"a scratch keeps the cue in the rack")
	var cue: int = game.rack.numbers.find(0)
	_check(cue >= 0 and CuePlacement.is_legal(game.rack.positions[cue],
		game.get_node("Simulation").layout, game.rack),
		"ball-in-hand places the cue legally")
	await _finish_game()


func _finish_game() -> void:
	var game = $Match
	# 4. stripes belong to player 1; each own-group pot keeps the turn
	_script(false, [_ev("ball-ball", 0, 9, 0.2), _ev("pocket-drop", 9, 0, 1.0)])
	await _play(-1)
	_check(game.get_current_player() == 1, "a stripe keeps player 1's turn")
	var wide: Array[ShotEvent] = [_ev("ball-ball", 0, 10, 0.2)]
	for n in [10, 11, 12, 13, 14, 15]:
		wide.append(_ev("pocket-drop", n, 0, 1.0))
	_script(false, wide)
	await _play(-1)
	_check(not game.get_state().remaining.has(15), "potted stripes leave the rack")

	# 5. the called 8 wins the game and announces no further turn
	_script(false, [_ev("ball-ball", 0, 8, 0.2), _ev("pocket-drop", 8, 3, 1.0)])
	await _play(3)
	_check(game.get_phase() == "GameOver", "the called 8 ends the match")
	_check(game.get_winner() == 1 and _winner == 1, "player 1 wins")
	for phase in ["AwaitingShot", "Striking", "Rolling", "Judging", "BallInHand", "GameOver"]:
		_check(_phases.has(phase), "phase entered: " + phase)
	_check(_turns == [2, 2, 1, 1, 1], "turn alternation: " + str(_turns))


func _ev(kind: String, ball: int, other: int, time: float) -> ShotEvent:
	var event := ShotEvent.new()
	event.kind = kind
	event.ball = ball
	event.other = other
	event.time = time
	return event


func _outcome(foul: bool) -> ShotOutcome:
	var outcome := ShotOutcome.new()
	outcome.phase = "settled"
	outcome.foul = foul
	return outcome


func _script(foul: bool, events: Array[ShotEvent]) -> void:
	$Match/Simulation.script_next(_outcome(foul), events)


func _play(called: int) -> void:
	var params := ShotParams.new()
	params.called_pocket = called
	$Match.take_shot(params)
	var guard := 0
	while $Match.get_phase() != "AwaitingShot" and $Match.get_phase() != "GameOver":
		if $Match.get_phase() == "BallInHand":
			PlacementHelper.place_cue($Match/BallInHandInput, $Match/Simulation.layout, $Match.rack)
		await get_tree().process_frame
		guard += 1
		if guard > 900:
			_fail("flow stalled in " + $Match.get_phase())
			return


func _on_turn(player: int) -> void:
	_turns.append(player)


func _on_finished(winner: int) -> void:
	_winner = winner


func _on_phase(phase: String, _player: int) -> void:
	_phases.append(phase)


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fail(note)


func _fail(note: String) -> void:
	_fails += 1
	printerr("  FAIL: ", note)
