extends Node3D

## Headless acceptance for #8's ball-in-hand: the input is live only in its
## phase, a cluster spot is refused with no signal, and a clean spot moves the
## cue in both the model rack and the visible ball before the turn resumes.
## Exit code is the number of failed assertions.

var _fails := 0
var _emits := 0
var _active_by_phase: Array[String] = []


func _ready() -> void:
	$Match/ShotPlayback.time_scale = 1000.0
	$Match/BallInHandInput.cue_ball_placed.connect(_on_placed)
	$Match/TurnFlow.phase_entered.connect(_on_phase)
	await _run()


func _run() -> void:
	var game = $Match
	var input := $Match/BallInHandInput
	var layout: TableLayout = $Match/Simulation.layout
	_check(not input.is_active(), "input idle before the foul")
	var opening: Array[ShotEvent] = [_ev("ball-ball", 0, 1, 0.3)]
	for n in [3, 5, 7, 9]:
		opening.append(_ev("cushion", n, 2, 0.5))
	_script(false, opening)
	$Match.take_shot(ShotParams.new())
	await _settle()
	_check(not input.is_active(), "input idle after the break")
	_check(game.get_current_player() == 2, "break passes the turn")
	_script(true, [_ev("pocket-drop", 0, 0, 0.9)])
	$Match.take_shot(ShotParams.new())
	await _settle()
	_check(game.get_phase() == "BallInHand", "scratch grants ball-in-hand")
	_check(input.is_active(), "input live only in BallInHand")
	_check(_active_by_phase.has("BallInHand:true"), "phase entry enabled input")
	_check(_active_by_phase.has("AwaitingShot:false"), "other phases keep it idle")

	var before := PackedVector3Array(game.rack.positions)
	var ball := $Match/BallRack.get_child(0) as Ball
	var visible_before := ball.position
	var cluster: Vector3 = game.rack.positions[1]
	_check(not input.place_at(cluster), "cluster spot rejected")
	_check(_emits == 0, "rejection emits no placement")
	_check(not input.is_last_legal(), "marker reports illegal")
	_check(game.rack.positions == before, "rejection leaves the rack unchanged")
	_check(ball.position == visible_before, "rejection leaves the ball unchanged")

	var spot := PlacementHelper.clean_spot(layout, game.rack)
	_check(CuePlacement.is_legal(spot, layout, game.rack), "chosen spot is clear")
	_check(input.place_at(spot), "clean spot accepted")
	_check(_emits == 1, "placement emitted once")
	_check(game.rack.positions[0].distance_to(spot) < 0.0001, "model cue moved")
	_check(ball.position.distance_to(spot) < 0.0001, "visible cue moved")
	_check(not input.is_active(), "input deactivated after placement")
	_check(game.get_phase() == "AwaitingShot", "flow resumes")
	_check(game.get_current_player() == 1, "incoming player shoots")
	print("ball-in-hand: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _settle() -> void:
	var guard := 0
	while not ["AwaitingShot", "BallInHand", "GameOver"].has($Match.get_phase()):
		await get_tree().process_frame
		guard += 1
		if guard > 900:
			_fail("flow stalled in " + $Match.get_phase())
			return


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


func _on_placed(_position: Vector3) -> void:
	_emits += 1


func _on_phase(phase: String, _player: int) -> void:
	_active_by_phase.append(phase + ":" + str($Match/BallInHandInput.is_active()))


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fail(note)


func _fail(note: String) -> void:
	_fails += 1
	printerr("  FAIL: ", note)
