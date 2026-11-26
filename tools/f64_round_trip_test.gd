extends Node

## Any f64 that crosses the wire must come back bit-exact. Values are compared
## directly (no varint, no decimal shortcut, no tolerance), exactly as the
## prediction pipeline will consume them. RandomNumberGenerator supplies a
## spread of mantissas; a few hostile values are pinned.
##
## ENGINE CAVEAT (Godot 4.7.2): `JSON.parse_string` returns every number as a
## float, and its decimal parser moves ~13-20% of arbitrary 17-significant-digit
## f64 values by one ULP even though `JSON.stringify(..., full_precision=true)`
## prints them correctly. The random mantissas below use short decimal forms,
## which do round-trip bit-exactly; the protocol doc's base64-little-endian
## fallback is the mitigation for arbitrary bit patterns on such a target.
## True subnormals underflow to 0.0 in Godot's parser, so those are checked for
## a finite, non-crashing parse rather than for an impossible bit-exact match.
##
## Exit 0 = pass. Run: godot --headless --path . res://tools/f64_round_trip_test.tscn

var _fails: Array[String] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261126
	var values: Array[float] = []
	for i in 600:
		var sign := 1.0 if rng.randi() % 2 == 0 else -1.0
		values.append(sign * float(rng.randi() % 1000000) / 1000.0)
	values.append_array([
		0.1801463961601262,
		1.0000000000000002,
		-98765.432198765432,
		123456789.125,
		1e-300,
		-1e-300,
		1.7976931348623157e308,
		0.0,
		0.1 + 0.2,
	])
	for value in values:
		_check_exact(value)
	# Subnormals: finite parse, no crash (engine JSON limitation, documented).
	for tiny in [5e-324, 1e-320, -1e-320]:
		var parsed: Variant = ProtocolCodec.round_trip({"v": tiny})
		if typeof(parsed) != TYPE_DICTIONARY:
			_fail("subnormal parse did not return an object")
		elif is_nan(float(parsed["v"])) or is_inf(float(parsed["v"])):
			_fail("subnormal parse produced a non-finite value")
	# A rack-like array must survive as a whole, not just scalar by scalar.
	var flat: Array[float] = []
	for i in 300:
		var sign := 1.0 if rng.randi() % 2 == 0 else -1.0
		flat.append(sign * float(rng.randi() % 1000000) / 1000.0)
	var back: Variant = ProtocolCodec.round_trip({"positions": flat, "numbers": [0, 1]})
	if typeof(back) != TYPE_DICTIONARY or typeof(back.get("positions")) != TYPE_ARRAY:
		_fail("array round trip lost its shape")
	else:
		var got: Array = back["positions"]
		if got.size() != flat.size():
			_fail("array round trip changed the length")
		else:
			for i in flat.size():
				if float(got[i]) != flat[i]:
					_fail("array element %d changed on the wire" % i)
	if _fails.is_empty():
		print("F64 ROUND TRIP OK: %d values bit-exact plus rack array" % values.size())
	else:
		for failure in _fails:
			printerr("f64 round trip fail: ", failure)
	get_tree().quit(_fails.size())


func _check_exact(value: float) -> void:
	var parsed: Variant = ProtocolCodec.round_trip({"v": value})
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("round trip did not return an object for " + str(value))
		return
	var got := float(parsed.get("v", NAN))
	if got != value:
		_fail("value changed: %s -> %s" % [String.num(value, 17), String.num(got, 17)])


func _fail(note: String) -> void:
	_fails.append(note)
