extends Node

## Server snapshots are untrusted. Every malformed example here must be
## rejected by SnapshotValidator BEFORE a RackState/MatchState is handed on.
## Exit 0 = pass. Run: godot --headless --path . res://tools/snapshot_validation_test.tscn

const RADIUS := 0.028575

var _fails: Array[String] = []


func _ready() -> void:
	var core := PoolCore.new()
	var layout := TableLayout.build(core.get_table_geometry())
	# A real snapshot passes in both strict and permissive modes.
	_accept(_good_rack(), layout, "good rack, strict")
	_accept(_good_rack(), null, "good rack, permissive")
	# Non-finite values arrive as JSON null (NaN) or an infinite exponent.
	_reject(JSON.parse_string("{\"positions\":[null,0.5,0.028575,0.5,0.5,0.028575],\"numbers\":[0,1],\"rotations\":[]}"),
		layout, "NaN as JSON null")
	_reject(JSON.parse_string("{\"positions\":[1e400,0.5,0.028575,0.5,0.5,0.028575],\"numbers\":[0,1],\"rotations\":[]}"),
		layout, "INF from a huge exponent")
	# Seventeen balls, duplicate numbers, wrong triple counts.
	var seventeen_positions: Array = []
	var seventeen_numbers: Array = []
	for i in 17:
		seventeen_numbers.append(i)
		seventeen_positions.append_array([0.25 + 0.01 * float(i), 0.5, RADIUS])
	_reject(_rack(seventeen_positions, seventeen_numbers, []), layout, "17 balls")
	_reject(_rack([0.25, 0.5, RADIUS, 0.5, 0.5, RADIUS], [0, 0], []),
		layout, "duplicate ball numbers")
	_reject(_rack([0.25, 0.5, RADIUS, 0.5, 0.5], [0, 1], []),
		layout, "wrong triple count")
	_reject(_rack([0.25, 0.5, RADIUS, 0.5, 0.5, RADIUS], [0, 16], [0.0, 0.0]),
		layout, "wrong rotation count")
	# Off-bed coordinates and a height far from the radius.
	_reject(_rack([999.0, 0.5, RADIUS, 0.5, 0.5, RADIUS], [0, 1], []),
		layout, "x outside the bed")
	_reject(_rack([0.25, -9.0, RADIUS, 0.5, 0.5, RADIUS], [0, 1], []),
		layout, "y outside the bed")
	_reject(_rack([0.25, 0.5, 0.5, 0.5, 0.5, RADIUS], [0, 1], []),
		layout, "z far above the bed")
	_reject(_rack(seventeen_positions, seventeen_numbers, []), null, "17 balls, permissive")
	# Closed enums: an unknown reason word, game-over reason and error code.
	var bad_commit := _good_commit()
	bad_commit["judgement"]["foul_reason"] = "totally_made_up"
	_reject_commit(bad_commit)
	var bad_over := _good_commit()
	bad_over["judgement"]["game_over"] = true
	bad_over["judgement"]["winner"] = 2
	bad_over["judgement"]["reason"] = "teleport"
	_reject_commit(bad_over)
	if SnapshotValidator.is_known_error_code("nope") \
			or not SnapshotValidator.is_known_error_code("bad_sequence"):
		_fail("error code enum is not closed")
	if SnapshotValidator.is_known_reason_word("nope") \
			or not SnapshotValidator.is_known_reason_word(""):
		_fail("reason-word enum is not closed")
	# A valid commit still passes.
	var ok := SnapshotValidator.validate_commit(_good_commit())
	if not ok["ok"]:
		_fail("good commit was rejected: " + str(ok["error"]))
	# Wire frames parse integer seq as TYPE_FLOAT. A real COMMIT must survive
	# the same JSON round trip the socket performs.
	var wire_commit: Variant = ProtocolCodec.parse(ProtocolCodec.stringify(_good_commit()))
	var wire_ok := SnapshotValidator.validate_commit(wire_commit)
	if not wire_ok["ok"]:
		_fail("wire-parsed commit was rejected: " + str(wire_ok["error"]))
	# GAME_OVER reason lives in its own message; a COMMIT judgement need not
	# carry it. A valid winner without `reason` must still be accepted.
	var over_commit := _good_commit()
	over_commit["judgement"] = {"foul_reason": "", "game_over": true, "winner": 1}
	var over_ok := SnapshotValidator.validate_commit(
		ProtocolCodec.parse(ProtocolCodec.stringify(over_commit)))
	if not over_ok["ok"]:
		_fail("game-over commit without reason was rejected: " + str(over_ok["error"]))
	if _fails.is_empty():
		print("SNAPSHOT VALIDATION OK: malformed frames rejected before the core")
	else:
		for failure in _fails:
			printerr("snapshot validation fail: ", failure)
	get_tree().quit(_fails.size())


func _good_rack() -> Dictionary:
	return _rack([0.25, 0.5625, RADIUS, 0.5, 0.5, RADIUS], [0, 1], [])


func _rack(positions: Array, numbers: Array, rotations: Array) -> Dictionary:
	return {"positions": positions, "numbers": numbers, "rotations": rotations}


func _good_commit() -> Dictionary:
	return {
		"seq": 1,
		"params": {
			"speed": 8.0,
			"level_aim_deg": 90.0,
			"elevation_deg": 0.0,
			"contact_x": 0.0,
			"contact_y": 0.0,
			"called_pocket": -1,
		},
		"hash": "77cb21802fe44b16",
		"judgement": {"foul_reason": "", "game_over": false, "winner": 0},
		"match": {
			"player": 1,
			"solids_player": 0,
			"remaining": [1, 2],
			"ball_in_hand": false,
			"break_next": false,
		},
		"rack": _good_rack(),
		"duration": 2.0,
		"remaining_time": 25.0,
		"events": [],
	}


func _accept(d: Variant, layout, label: String) -> void:
	var result := SnapshotValidator.validate_rack(d, layout)
	if not result["ok"]:
		_fail(label + " was rejected: " + str(result["error"]))
	elif not result["rack"] is RackState:
		_fail(label + " returned no RackState")


func _reject(d: Variant, layout, label: String) -> void:
	var result := SnapshotValidator.validate_rack(d, layout)
	if result["ok"]:
		_fail(label + " was accepted")
	if not result.has("rack") or not result["rack"] is RackState:
		_fail(label + " returned no safe rack placeholder")


func _reject_commit(d: Variant) -> void:
	var result := SnapshotValidator.validate_commit(d)
	if result["ok"]:
		_fail("a commit with an unknown enum was accepted")


func _fail(note: String) -> void:
	_fails.append(note)
