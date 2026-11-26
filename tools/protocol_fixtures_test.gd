extends Node

## Golden message fixtures from the wire contract, kept inline so the harness
## has no external data file. Every frame is serialized with ProtocolCodec's
## full-precision JSON and parsed back to the same numeric frame.
##
## Godot 4.7's JSON parser returns every number as a float, so an integer 7 in
## the source fixture parses back as 7.0; `_same` compares numeric leaves by
## value (exactly, not approximately) rather than by Variant type. The f64
## value itself must still survive byte-exactly, which the long decimal below
## checks explicitly.
##
## Exit 0 = pass. Run: godot --headless --path . res://tools/protocol_fixtures_test.tscn

const HOSTILE := 0.1801463961601262

var _fails: Array[String] = []


func _ready() -> void:
	var fixtures := _fixtures()
	for key in fixtures.keys():
		var original: Dictionary = fixtures[key]
		var text := ProtocolCodec.stringify(original)
		var parsed: Variant = ProtocolCodec.parse(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			_fail(key + ": parse did not return an object")
			continue
		if not _same(parsed, original):
			_fail(key + ": round trip changed the frame")
		if not parsed.has("type") or str(parsed["type"]) != str(original["type"]):
			_fail(key + ": type field changed")
	# The full-precision flag must keep the long decimal verbatim.
	var precision_text := ProtocolCodec.stringify({"v": HOSTILE})
	if not precision_text.contains("0.1801463961601262"):
		_fail("full precision lost the hostile value: " + precision_text)
	if float(ProtocolCodec.parse(precision_text)["v"]) != HOSTILE:
		_fail("hostile value changed on parse")
	# The catalogue's two error paths must both be present and closed.
	if not fixtures.has("ERROR_version_mismatch") or not fixtures.has("ERROR_canary_mismatch"):
		_fail("one of the two ERROR paths is missing")
	if _fails.is_empty():
		print("PROTOCOL FIXTURES OK: %d golden frames round-trip at full precision" % fixtures.size())
	else:
		for failure in _fails:
			printerr("protocol fixture fail: ", failure)
	get_tree().quit(_fails.size())


## Exact numeric equality, allowing the engine's int -> float parse quirk.
func _same(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta == TYPE_DICTIONARY or tb == TYPE_DICTIONARY:
		if ta != TYPE_DICTIONARY or tb != TYPE_DICTIONARY or a.size() != b.size():
			return false
		for key in a.keys():
			if not b.has(key) or not _same(a[key], b[key]):
				return false
		return true
	var a_array := ta == TYPE_ARRAY or ta == TYPE_PACKED_INT32_ARRAY or ta == TYPE_PACKED_FLOAT64_ARRAY
	var b_array := tb == TYPE_ARRAY or tb == TYPE_PACKED_INT32_ARRAY or tb == TYPE_PACKED_FLOAT64_ARRAY
	if a_array or b_array:
		if not a_array or not b_array or a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	var a_number := ta == TYPE_INT or ta == TYPE_FLOAT
	var b_number := tb == TYPE_INT or tb == TYPE_FLOAT
	if a_number or b_number:
		return a_number and b_number and float(a) == float(b)
	return a == b


func _fail(note: String) -> void:
	_fails.append(note)


func _params() -> Dictionary:
	return {
		"speed": 8.0,
		"level_aim_deg": 90.0,
		"elevation_deg": 12.0,
		"contact_x": 0.0,
		"contact_y": HOSTILE,
		"called_pocket": -1,
	}


func _match() -> Dictionary:
	return {
		"player": 1,
		"solids_player": 0,
		"remaining": [1, 2, 3, 4, 5, 6, 7, 8],
		"ball_in_hand": false,
		"break_next": true,
	}


func _rack() -> Dictionary:
	return {
		"positions": [0.25, 0.5625, 0.028575,
			0.5 + HOSTILE * 0.01, 0.5, 0.028575],
		"numbers": [0, 1],
		"rotations": [],
	}


func _fixtures() -> Dictionary:
	var aim := {
		"type": "AIM",
		"room": "room-1",
		"level_aim_deg": 90.0,
		"elevation_deg": 3.5,
		"english_x": HOSTILE,
		"english_y": -0.125,
		"pull_m": 0.02,
		"speed_m_s": 6.75,
	}
	var place := {
		"type": "PLACE_PREVIEW",
		"room": "room-1",
		"place": {"x": HOSTILE, "y": 0.5625},
	}
	var commit := {
		"type": "COMMIT",
		"seq": 7,
		"params": _params(),
		"hash": "77cb21802fe44b16",
		"outcome": {
			"phase": "settled",
			"elapsed_time": 3.5,
			"foul": false,
			"miscue": false,
			"pocketed": [],
			"off_table": [],
			"error": "",
		},
		"events": [],
		"judgement": {
			"foul_reason": "",
			"next_player": 2,
			"ball_in_hand": false,
			"re_rack": false,
			"solids_player": 0,
			"game_over": false,
			"winner": 0,
		},
		"match": _match(),
		"rack": _rack(),
		"duration": 3.5,
		"remaining_time": 26.5,
	}
	return {
		"HELLO": {
			"type": "HELLO",
			"protocol": "1",
			"model": "1.9",
			"rules": "1",
			"intent": "1",
			"canary": "0123456789abcdef",
			"name": "Player",
		},
		"ROOM_STATE": {
			"type": "ROOM_STATE",
			"room": "room-1",
			"match": _match(),
			"rack": _rack(),
			"seq": 7,
			"remaining_time": 28.5,
		},
		"SHOT": {
			"type": "SHOT",
			"room": "room-1",
			"seq": 7,
			"params": _params(),
			"place": {"x": HOSTILE, "y": 0.5625},
		},
		"COMMIT": commit,
		"AIM": aim,
		"PLACE_PREVIEW": place,
		"GAME_OVER": {"type": "GAME_OVER", "winner": 2, "reason": "rules"},
		"ERROR_version_mismatch": {
			"type": "ERROR",
			"code": "version_mismatch",
			"seq": -1,
			"message": "protocol 1 is required",
			"expected": {"protocol": "1", "model": "1.9", "rules": "1", "intent": "1"},
		},
		"ERROR_canary_mismatch": {
			"type": "ERROR",
			"code": "canary_mismatch",
			"seq": -1,
			"message": "canary differs",
			"expected": {"canary": "0123456789abcdef"},
		},
	}
