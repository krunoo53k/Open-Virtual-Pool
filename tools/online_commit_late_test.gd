extends Node3D

## Regression: a COMMIT that arrives AFTER the local replay has reached
## Judging must still be applied. The judgement_pending signal fires once, so
## storing the commit without applying it used to leave the match stuck in
## Judging forever. Exit code = failed assertions.

var _fails := 0


func _ready() -> void:
	var fake := FakeOnlineSession.new()
	add_child(fake)
	var packed: PackedScene = load("res://scenes/online/online_match/online_match.tscn")
	var online = packed.instantiate()
	online.session = fake
	online.seat = 0
	add_child(online)
	var game: Match = online.match_node
	var rack_wire: Variant = JSON.parse_string(JSON.stringify(
		PoolSimulation.rack_dict(game.rack), "", false, true))
	var match_wire := {"player": 1, "solids_player": 0,
		"remaining": Array(game.state.remaining), "ball_in_hand": false,
		"break_next": true}
	fake.room_state.emit({"seq": 0, "match": match_wire, "rack": rack_wire})
	await get_tree().process_frame
	game.get_node("ShotPlayback").time_scale = 1000.0
	var params := ShotParams.new()
	params.speed = 4.0
	params.level_aim_deg = 90.0
	game.get_node("Shooter1").shot_committed.emit(params)
	# Wait for playback to finish and the held Judging phase to begin.
	var guard := 0
	while game.get_phase() != "Judging" and guard < 120:
		await get_tree().process_frame
		guard += 1
	_check(game.get_phase() == "Judging", "local playback reached Judging")
	_check(online._active_commit.is_empty(), "no commit yet while judging is held")
	# The authoritative result arrives late (latency / slow server).
	fake.commit.emit({"seq": 1, "params": PoolSimulation.params_dict(params),
		"hash": "serverhash", "judgement": {"foul_reason": "", "next_player": 2},
		"match": match_wire, "rack": rack_wire, "remaining_time": 25.0})
	for _i in range(6):
		await get_tree().process_frame
	_check(online._confirmed_seq == 1, "a late COMMIT is applied")
	_check(game.get_phase() == "AwaitingShot", "the flow leaves Judging after a late COMMIT")
	_check(not online._playing, "playback state is cleared")
	print("online late commit: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fails += 1
		printerr("  FAIL: ", note)
