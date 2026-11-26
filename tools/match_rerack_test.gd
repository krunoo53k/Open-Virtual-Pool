extends Node3D

## Headless regression for a re-rack ruling. The rack must come back from its
## seeded layout, not stay in the post-break frame with potted balls missing.
## The tools-only adapter scripts the 8-on-the-break event stream; the ruling,
## the rack fold and the match flow are real.

var _fails := 0


func _ready() -> void:
	var game = $Match
	var initial_numbers := PackedInt32Array(game.rack.numbers)
	var initial_positions := RackState.display_from_flat(game.rack.positions)
	game.get_node("ShotPlayback").time_scale = 1000.0  # finish the replay in one frame

	# the 8 potted on a legal break: re_rack, no foul, shooter breaks again
	var events: Array[ShotEvent] = [_ev("ball-ball", 0, 1, 0.3)]
	for n in [3, 5, 7, 9]:
		events.append(_ev("cushion", n, 2, 0.5))
	events.append(_ev("pocket-drop", 8, 0, 1.0))
	var outcome := ShotOutcome.new()
	outcome.phase = "settled"
	game.get_node("Simulation").script_next(outcome, events)
	game.take_shot(ShotParams.new())
	var guard := 0
	while game.get_phase() != "AwaitingShot" and game.get_phase() != "GameOver":
		await get_tree().process_frame
		guard += 1
		if guard > 900:
			_fail("re-rack flow stalled in " + game.get_phase())
			break

	_check(game.rack.numbers == initial_numbers, "re-rack restores every ball number")
	_check(RackState.display_from_flat(game.rack.positions) == initial_positions,
		"re-rack restores the seeded spots")
	_check(game.get_state().remaining.size() == 15, "re-rack restores the remaining list")
	_check(game.get_state().break_next, "re-rack leaves the next stroke a break")
	var visible := 0
	for child in game.get_node("BallRack").get_children():
		if child is Ball and child.visible:
			visible += 1
	_check(visible == 16, "re-rack shows every ball again")
	print("match re-rack test: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _ev(kind: String, ball: int, other: int, time: float) -> ShotEvent:
	var event := ShotEvent.new()
	event.kind = kind
	event.ball = ball
	event.other = other
	event.time = time
	return event


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fail(note)


func _fail(note: String) -> void:
	_fails += 1
	printerr("  FAIL: ", note)
