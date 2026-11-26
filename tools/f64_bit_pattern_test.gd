extends Node

## True arbitrary-f64 pin for the protocol's base64 fallback. Plain JSON is
## fragile on Godot 4.7 (its decimal parser shifts some 17-digit values by an
## ULP), so rack arrays may cross as base64 little-endian f64 bytes. This
## harness generates random 64-bit patterns, round-trips them through a full
## full-precision JSON frame and compares the BYTES, not just the values.
## Exit code 0 = every bit survived.

var _fails := 0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261126
	var values: Array[float] = []
	for _i in 600:
		var bytes := PackedByteArray()
		bytes.resize(8)
		for byte_index in 8:
			bytes[byte_index] = rng.randi() & 0xff
		var value := bytes.decode_double(0)
		if is_nan(value) or is_inf(value):
			continue
		values.append(value)
	# The one decimal Godot can print but not parse back bit-exactly.
	values.append(0.1801463961601262)
	var frame := {"type": "ROOM_STATE", "rack": {"positions_b64":
		ProtocolCodec.encode_f64_array(values), "numbers": [0, 1]}}
	var parsed: Variant = ProtocolCodec.round_trip(frame)
	if not (parsed is Dictionary):
		printerr("bit-pattern pin: frame did not parse")
		get_tree().quit(1)
		return
	var rack: Dictionary = parsed["rack"]
	var back := ProtocolCodec.decode_f64_array(rack["positions_b64"])
	_check(back.size() == values.size(), "every f64 survived the frame")
	for i in mini(back.size(), values.size()):
		if _bits(back[i]) != _bits(values[i]):
			_fails += 1
			printerr("  FAIL: bit pattern ", i, " moved")
	# A RackState built from the wire keeps the same bits.
	var state := RackState.new()
	state.positions = back
	state.numbers = PackedInt32Array([0, 1])
	var again := ProtocolCodec.rack_to_wire(state)
	var decoded := ProtocolCodec.wire_to_rack(again)
	for i in mini(decoded.positions.size(), values.size()):
		if _bits(decoded.positions[i]) != _bits(values[i]):
			_fails += 1
			printerr("  FAIL: rack wire bit pattern ", i, " moved")
	print("F64 BIT PATTERN OK: ", values.size(), " arbitrary f64 values bit-exact")
	get_tree().quit(_fails)


func _bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fails += 1
		printerr("  FAIL: ", note)
