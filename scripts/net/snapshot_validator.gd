class_name SnapshotValidator
extends RefCounted

## Untrusted-server boundary. The lobby accepts arbitrary ws:// URLs, so every
## snapshot is validated here BEFORE a RackState or MatchState exists, and
## before any signal hands it to the core. Nothing in this file simulates or
## rules anything: it only checks shape, finiteness, ranges and closed enums.
##
## `validate_rack(d, layout)` returns {"ok", "error", "rack"} with a (possibly
## empty) RackState always present, so a caller can handle rejection without a
## null check. Passing a null layout means permissive mode: structure,
## finiteness and a generous magnitude bound only, no bed placement test.

const MAX_BALLS := 16

## Core-frame ball radius tolerance and the small positive lift allowed above
## the bed (balls can be momentarily off the cloth in a snapshot).
const Z_TOLERANCE := 0.005
const Z_LIFT_LIMIT := 0.05
const BOUND_EPSILON := 0.0001

## Reject absurd coordinates even when no layout is available.
const MAX_ABS_COORD := 1.0e6

## Closed vocabularies from protocol §6. Unknown values are malformed.
const ERROR_CODES: Array[String] = [
	"version_mismatch", "canary_mismatch", "not_your_turn", "wrong_phase",
	"bad_sequence", "shot_deadline", "invalid_params", "invalid_placement",
	"unknown_message", "rate_limited", "room_full", "room_gone", "malformed",
]

const REASON_WORDS: Array[String] = [
	"scratch", "ball_off_table", "wrong_group_first_contact", "no_contact",
	"no_rail_after_contact", "illegal_break", "miscue", "incomplete_shot",
]

const GAME_OVER_REASONS: Array[String] = ["rules", "forfeit", "disconnect"]

const SHOT_KEYS: Array[String] = [
	"speed", "level_aim_deg", "elevation_deg", "contact_x", "contact_y", "called_pocket",
]


static func is_known_error_code(code: String) -> bool:
	return code in ERROR_CODES


static func is_known_reason_word(reason: String) -> bool:
	return reason.is_empty() or reason in REASON_WORDS


static func is_known_game_over_reason(reason: String) -> bool:
	return reason in GAME_OVER_REASONS


static func _bad(error: String) -> Dictionary:
	return {"ok": false, "error": error, "rack": RackState.new()}


static func _finite_number(value: Variant) -> bool:
	var t := typeof(value)
	if t == TYPE_INT:
		return true
	if t != TYPE_FLOAT:
		return false
	return not is_nan(value) and not is_inf(value)


## A JSON null (from NaN), INF (from a huge exponent) or a non-number is never
## allowed into a numeric field.
static func _numbers(values: Variant, label: String) -> String:
	if typeof(values) != TYPE_ARRAY and typeof(values) != TYPE_PACKED_FLOAT64_ARRAY \
			and typeof(values) != TYPE_PACKED_VECTOR3_ARRAY:
		if typeof(values) != TYPE_PACKED_INT32_ARRAY:
			return label + " is not an array"
	for v in values:
		if not _finite_number(v):
			return label + " contains a non-finite value"
		if abs(float(v)) > MAX_ABS_COORD:
			return label + " contains an out-of-range value"
	return ""


## Validate a rack snapshot. Layout may be a TableLayout or a geometry
## Dictionary; when null only the permissive bounds are enforced.
static func validate_rack(d: Variant, layout_or_null) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		return _bad("rack is not an object")
	var positions: Variant = d.get("positions", null)
	var numbers: Variant = d.get("numbers", null)
	var rotations: Variant = d.get("rotations", [])
	if positions == null or numbers == null:
		return _bad("rack is missing positions or numbers")
	var fail := _numbers(positions, "positions")
	if fail != "":
		return _bad(fail)
	fail = _numbers(rotations, "rotations")
	if fail != "":
		return _bad(fail)
	var count: int = _count(numbers)
	if count < 0:
		return _bad("numbers is not an array of integers")
	if count > MAX_BALLS:
		return _bad("rack has more than 16 balls")
	if _count(positions) != count * 3:
		return _bad("positions must hold three numbers per ball")
	if _count(rotations) != 0 and _count(rotations) != count * 3:
		return _bad("rotations must be empty or hold three numbers per ball")
	var seen := {}
	for i in count:
		var n := int(_element(numbers, i))
		if n < 0 or n > 15:
			return _bad("ball number out of range: " + str(n))
		if seen.has(n):
			return _bad("duplicate ball number: " + str(n))
		seen[n] = true
	var radius := 0.028575
	var length := 2.54
	var width := 1.267
	if layout_or_null != null:
		if typeof(layout_or_null) == TYPE_DICTIONARY:
			radius = float(layout_or_null.get("ball_radius", radius))
			length = float(layout_or_null.get("length", length))
			width = float(layout_or_null.get("width", width))
		else:
			radius = float(layout_or_null.get("ball_radius"))
			length = float(layout_or_null.get("length"))
			width = float(layout_or_null.get("width"))
	for i in count:
		var x := float(_element(positions, i * 3))
		var y := float(_element(positions, i * 3 + 1))
		var z := float(_element(positions, i * 3 + 2))
		if layout_or_null != null:
			if x < -radius - BOUND_EPSILON or x > length + radius + BOUND_EPSILON:
				return _bad("ball outside the bed in x: " + str(x))
			if y < -radius - BOUND_EPSILON or y > width + radius + BOUND_EPSILON:
				return _bad("ball outside the bed in y: " + str(y))
			if z < radius - Z_TOLERANCE or z > radius + Z_LIFT_LIMIT:
				return _bad("ball height is not near the bed: " + str(z))
	return {"ok": true, "error": "", "rack": ProtocolCodec.dict_to_rack(d)}


static func _count(value: Variant) -> int:
	match typeof(value):
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			return value.size()
		_:
			return -1


static func _element(value: Variant, index: int) -> Variant:
	return value[index]


## Validate the between-shots match state (closed players 1/2, closed group
## owner 0/1/2, object numbers 1..15, booleans only).
static func validate_match(d: Variant) -> Dictionary:
	var state := MatchState.new()
	if typeof(d) != TYPE_DICTIONARY:
		return {"ok": false, "error": "match is not an object", "match": state}
	var player := int(d.get("player", 1))
	if player != 1 and player != 2:
		return {"ok": false, "error": "match player is not 1 or 2", "match": state}
	var solids := int(d.get("solids_player", 0))
	if solids < 0 or solids > 2:
		return {"ok": false, "error": "match solids_player out of range", "match": state}
	var remaining: Variant = d.get("remaining", [])
	if _count(remaining) < 0:
		return {"ok": false, "error": "match remaining is not an array", "match": state}
	var seen := {}
	for i in _count(remaining):
		var n := int(_element(remaining, i))
		if n < 1 or n > 15:
			return {"ok": false, "error": "remaining ball number out of range", "match": state}
		if seen.has(n):
			return {"ok": false, "error": "duplicate remaining ball number", "match": state}
		seen[n] = true
	state.player = player
	state.solids_player = solids
	state.ball_in_hand = bool(d.get("ball_in_hand", false))
	state.break_next = bool(d.get("break_next", true))
	state.remaining = _ints(remaining)
	return {"ok": true, "error": "", "match": state}


static func _ints(value: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	for item in value:
		out.append(int(item))
	return out


## Validate a COMMIT before it reaches the match composer. Checks the closed
## reason-word enum, the closed error-code enum (when an error is embedded),
## the closed GAME_OVER reasons, plus the same snapshot gates above.
static func validate_commit(d: Variant) -> Dictionary:
	var result := {"ok": false, "error": "", "commit": null}
	if typeof(d) != TYPE_DICTIONARY:
		result["error"] = "commit is not an object"
		return result
	# Godot's JSON parser returns every number as a float, including integer
	# literals. Require an integral, finite, non-negative number rather than
	# the Variant TYPE_INT, or every commit parsed off the socket is rejected.
	var seq_value: Variant = d.get("seq", null)
	if typeof(seq_value) != TYPE_INT and typeof(seq_value) != TYPE_FLOAT:
		result["error"] = "commit seq is missing or not a number"
		return result
	var seq := float(seq_value)
	if not is_finite(seq) or seq < 0.0 or floorf(seq) != seq:
		result["error"] = "commit seq is negative, non-finite or fractional"
		return result
	var params: Variant = d.get("params", null)
	if typeof(params) != TYPE_DICTIONARY:
		result["error"] = "commit params is not an object"
		return result
	for key in SHOT_KEYS:
		if not params.has(key) or not _finite_number(params[key]):
			result["error"] = "commit params field is missing or non-finite: " + key
			return result
	if str(d.get("hash", "")).is_empty():
		result["error"] = "commit hash is empty"
		return result
	var judgement: Variant = d.get("judgement", {})
	if typeof(judgement) != TYPE_DICTIONARY:
		result["error"] = "commit judgement is not an object"
		return result
	var reason := str(judgement.get("foul_reason", ""))
	if not is_known_reason_word(reason):
		result["error"] = "unknown judgement reason word: " + reason
		return result
	if bool(judgement.get("game_over", false)):
		var winner := int(judgement.get("winner", 0))
		if winner != 1 and winner != 2:
			result["error"] = "game over winner is not 1 or 2"
			return result
		# `reason` belongs to the GAME_OVER catalogue entry; COMMIT carries a
		# judgement without it. Validate it only when the server supplied one.
		var over_reason := str(judgement.get("reason", ""))
		if over_reason != "" and not is_known_game_over_reason(over_reason):
			result["error"] = "unknown game over reason: " + over_reason
			return result
	var match_check := validate_match(d.get("match", {}))
	if not match_check["ok"]:
		result["error"] = "commit " + str(match_check["error"])
		return result
	var rack_check := validate_rack(d.get("rack", {}), null)
	if not rack_check["ok"]:
		result["error"] = "commit " + str(rack_check["error"])
		return result
	for key in ["duration", "remaining_time"]:
		if d.has(key) and not _finite_number(d[key]):
			result["error"] = "commit " + key + " is non-finite"
			return result
	var events: Variant = d.get("events", [])
	if _count(events) >= 0:
		for event in events:
			if typeof(event) == TYPE_DICTIONARY and event.has("reason"):
				if not is_known_reason_word(str(event["reason"])):
					result["error"] = "unknown event reason word: " + str(event["reason"])
					return result
	var embedded: Variant = d.get("error", null)
	if embedded != null and typeof(embedded) == TYPE_DICTIONARY:
		var code := str(embedded.get("code", ""))
		if not is_known_error_code(code):
			result["error"] = "unknown embedded error code: " + code
			return result
	result["ok"] = true
	result["commit"] = d
	return result
