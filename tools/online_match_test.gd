extends Node3D

## Headless acceptance for the online composer: it reuses the real Match
## scenes, holds the ruling for the authoritative COMMIT, sends one atomic
## SHOT with post-serialization params, rolls back on ERROR, keeps commits in
## sequence order and only applies held aim updates once playback ends.
## Exit code is the number of failed assertions.

var _fails := 0


func _ready() -> void:
	var tree := get_tree()
	var fake := FakeOnlineSession.new()
	add_child(fake)
	var packed: PackedScene = load("res://scenes/online/online_match/online_match.tscn")
	var online = packed.instantiate()
	online.session = fake
	online.seat = 0
	add_child(online)
	var game: Match = online.match_node
	_check(game != null, "the hotseat Match scene was reused")
	var flow: MatchFlow = game.get_node("MatchFlow")
	var sim: PoolSimulation = game.get_node("Simulation")
	_check(PoolSimulation.USE_F64_INTENT, "stage 2 is enabled")
	_check(sim.core != null and sim.core.has_method("simulate_from_intent_f64"),
		"the loaded engine exposes the f64 intent entry point")
	_check(flow.use_serialized_resolve, "prediction runs on wire values")
	_check(flow.suppress_judging, "local ruling is held for COMMIT")
	var remote_script: Script = game.get_node("Shooter2").get_script()
	_check(remote_script != null and remote_script.resource_path.ends_with("remote_shooter.gd"),
		"the remote seat uses RemoteShooter")
	_check_commit_queue()

	# A confirmed snapshot from the server seeds the shared resources.
	var rack_wire := _wire(PoolSimulation.rack_dict(game.rack))
	var match_wire := {
		"player": 1, "solids_player": 0, "remaining": Array(game.state.remaining),
		"ball_in_hand": false, "break_next": true,
	}
	fake.room_state.emit({"seq": 0, "match": match_wire, "rack": rack_wire,
		"remaining_time": 30.0})
	await _frames(2)
	_check(online._confirmed_seq == 0, "the confirmed seq is tracked")
	_check(game.get_phase() == "AwaitingShot", "ROOM_STATE opens the turn")

	# A local stroke becomes one SHOT; prediction runs before playback.
	var params := ShotParams.new()
	params.speed = 4.0
	params.level_aim_deg = 90.0
	game.get_node("Shooter1").shot_committed.emit(params)
	_check(fake.has_type("SHOT"), "a local stroke sends SHOT")
	_check(online._in_flight.has(1), "the predicted hash is stored by seq")
	var sent_shot := {}
	for item in fake.sent:
		if String(item.get("type", "")) == "SHOT":
			sent_shot = item
	if online._in_flight.has(1):
		_check(sent_shot.get("params", {}) == online._in_flight[1]["params"],
			"prediction runs on the exact values put on the wire")
	_check(game.get_phase() == "Rolling", "local prediction plays immediately")

	# ERROR cancels the trace and restores the last confirmed rack.
	fake.error_received.emit("invalid_params", "rejected by server", 1)
	await _frames(2)
	_check(not game.get_node("ShotPlayback").has_active_shot(),
		"a rejected shot leaves no animated balls")
	_check(game.get_phase() == "AwaitingShot", "ERROR resumes the turn")
	_check(_flat_equal(game.rack.positions, rack_wire["positions"]),
		"ERROR restores the confirmed rack")

	# An opponent COMMIT replays from the confirmed rack with echoed params,
	# then the authoritative snapshot wins over any local prediction.
	game.get_node("ShotPlayback").time_scale = 1000.0
	var second := match_wire.duplicate(true)
	second["player"] = 2
	fake.aim_received.emit({"level_aim_deg": 12.0, "elevation_deg": 1.0,
		"english_x": 0.001, "english_y": 0.0, "pull_m": 0.01, "speed_m_s": 3.0})
	fake.commit.emit({"seq": 1, "params": PoolSimulation.params_dict(params),
		"hash": "serverhash", "judgement": {"foul_reason": "", "next_player": 2,
		"ball_in_hand": false, "re_rack": false, "solids_player": 0,
		"game_over": false, "winner": 0},
		"match": second, "rack": rack_wire, "remaining_time": 25.0})
	await _frames(14)
	_check(online._confirmed_seq == 1, "COMMIT advances the confirmed seq")
	_check(game.get_state().player == 2, "the authoritative turn is applied")
	_check(not online._playing, "playback ends after the commit")
	var proxy: RemoteAimProxy = online._remote_proxy()
	_check(proxy != null, "the remote aim proxy is reachable")
	if proxy != null:
		await _frames(4)
		var aim_value := proxy.get_level_aim_deg()
		_check(aim_value < 90.0 and aim_value >= 12.0,
			"held aim interpolates toward the target once playback ends")
	_check(fake.has_type("LEAVE") == false, "no leave was sent during the match")
	online.leave_match()
	_check(fake.has_type("LEAVE"), "leaving the match is a forfeit")
	print("online match: ", _fails, " failed assertions")
	# leave_match changes scenes: quit through the tree captured before it.
	tree.quit(_fails)


func _wire(value: Variant) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value, "", false, true))
	return parsed if parsed is Dictionary else {}


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _flat_equal(actual: Array[float], expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for i in actual.size():
		if not is_equal_approx(float(actual[i]), float(expected[i])):
			return false
	return true


func _check_commit_queue() -> void:
	var queue := CommitQueue.new()
	_check(queue.push({"seq": 3}), "queue accepts seq 3")
	_check(queue.push({"seq": 1}), "queue accepts seq 1 out of order")
	_check(queue.push({"seq": 2}), "queue accepts seq 2")
	_check(not queue.push({"seq": 2}), "queue drops duplicates")
	_check(int(queue.peek().get("seq", -1)) == 1, "queue peek is the lowest seq")
	_check(int(queue.pop().get("seq", -1)) == 1, "queue pops in order")
	queue.drop_stale(2)
	_check(queue.size() == 1, "queue drops stale commits")


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fails += 1
		printerr("  FAIL: ", note)
