class_name ProtocolCodec
extends RefCounted

## The wire codec. Every frame goes through `stringify`/`parse` here so no
## caller can accidentally use Godot's lossy default float formatting.
##
## NOTE ON THE ENGINE SIGNATURE: the wire contract's `JSON.stringify(value,
## true)` shorthand means "full precision". In Godot 4.7 the actual signature
## is `stringify(data, indent = "", sort_keys = false, full_precision = false)`,
## so full precision is the FOURTH argument. `stringify()` below is the one
## place that spelling lives; everything else calls it.

const PLACE_Z := 0.0  # height is implied on the wire; never serialised.


static func stringify(value: Variant) -> String:
	return JSON.stringify(value, "", false, true)


static func parse(text: String) -> Variant:
	return JSON.parse_string(text)


## One full-precision stringify -> parse cycle. Prediction must run on the
## values that come back from here, never on the caller's pre-wire locals.
static func round_trip(value: Variant) -> Variant:
	return parse(stringify(value))


## The six scalars of ShotParams, in the closed order of protocol §7.
static func params_to_dict(params: ShotParams) -> Dictionary:
	return {
		"speed": float(params.speed),
		"level_aim_deg": float(params.level_aim_deg),
		"elevation_deg": float(params.elevation_deg),
		"contact_x": float(params.contact_x),
		"contact_y": float(params.contact_y),
		"called_pocket": int(params.called_pocket),
	}


static func dict_to_params(d: Dictionary) -> ShotParams:
	var params := ShotParams.new()
	params.speed = float(d.get("speed", params.speed))
	params.level_aim_deg = float(d.get("level_aim_deg", params.level_aim_deg))
	params.elevation_deg = float(d.get("elevation_deg", params.elevation_deg))
	params.contact_x = float(d.get("contact_x", params.contact_x))
	params.contact_y = float(d.get("contact_y", params.contact_y))
	params.called_pocket = int(d.get("called_pocket", params.called_pocket))
	return params


## Flat CORE-frame triples. NO display transform is applied anywhere here.
static func rack_to_dict(rack: RackState) -> Dictionary:
	var positions: Array = []
	for v in rack.positions:
		positions.append(float(v))
	var rotations: Array = []
	for v in rack.rotations:
		rotations.append(float(v))
	var numbers: Array = []
	for n in rack.numbers:
		numbers.append(int(n))
	return {
		"positions": positions,
		"numbers": numbers,
		"rotations": rotations,
	}


static func dict_to_rack(d: Dictionary) -> RackState:
	var rack := RackState.new()
	rack.positions = _floats(d.get("positions", []))
	rack.numbers = _ints(d.get("numbers", []))
	rack.rotations = _floats(d.get("rotations", []))
	return rack


## --- Base64 little-endian fallback (protocol §4) -------------------------
## Godot 4.7's JSON parser moves some arbitrary 17-digit decimals by one ULP,
## and underflows subnormals, even though `stringify(..., full_precision=true)`
## prints them correctly. For targets where that matters, the protocol allows
## rack arrays to cross as base64 little-endian f64 bytes. `rack_to_wire` /
## `wire_to_rack` implement that form; both sides must agree to use it (the
## golden fixtures stay in the plain-array form).
static func encode_f64_array(values: Variant) -> String:
	if values.is_empty():
		return ""  # Godot's raw_to_base64 rejects an empty buffer.
	var word := PackedByteArray()
	word.resize(8)
	var raw := PackedByteArray()
	for value in values:
		word.encode_double(0, float(value))
		raw.append_array(word)
	return Marshalls.raw_to_base64(raw)


static func decode_f64_array(text: String) -> Array[float]:
	var raw := Marshalls.base64_to_raw(text)
	var out: Array[float] = []
	for i in range(raw.size() / 8):
		out.append(raw.decode_double(i * 8))
	return out


static func rack_to_wire(rack: RackState) -> Dictionary:
	var numbers: Array = []
	for n in rack.numbers:
		numbers.append(int(n))
	return {
		"positions_b64": encode_f64_array(rack.positions),
		"numbers": numbers,
		"rotations_b64": encode_f64_array(rack.rotations),
	}


static func wire_to_rack(d: Dictionary) -> RackState:
	var rack := RackState.new()
	rack.positions = decode_f64_array(String(d.get("positions_b64", "")))
	rack.numbers = _ints(d.get("numbers", []))
	rack.rotations = decode_f64_array(String(d.get("rotations_b64", "")))
	return rack


## A place is a core-frame plane point. The cue's z is the ball radius and is
## implied by the receiver; it is deliberately NOT on the wire (protocol §4).
static func place_to_dict(place: Vector3) -> Dictionary:
	return {"x": float(place.x), "y": float(place.y)}


## z is a placeholder only: callers must supply the radius from their layout.
static func dict_to_place(d: Dictionary) -> Vector3:
	return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), PLACE_Z)


static func _floats(value: Variant) -> Array[float]:
	var out: Array[float] = []
	for item in value:
		out.append(float(item))
	return out


static func _ints(value: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	for item in value:
		out.append(int(item))
	return out
