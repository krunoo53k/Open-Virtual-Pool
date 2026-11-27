class_name DeterminismCanary
extends RefCounted

## Local diagnostic fingerprint — NOT the canary sent in HELLO.
##
## The handshake value is published by the engine through
## `PoolCore.get_build_info()` and mirrored in `compat/compat.json`;
## `ProtocolVersions.hello_fields()` reads it from there. The engine's exact
## canary recipe is documented in the engine repo's
## `docs/online-multiplayer-e0.md` §4 and MUST be implemented from that source,
## not from the provisional recipe below.
##
## `compute()` runs three fixed shots and folds their hashes with FNV-1a as a
## local sanity check. It predates the engine's shared canary helper and does
## NOT reproduce the published value. Any fault (missing core, faulted shot,
## empty hash) returns "" after a loud push_error so a harness cannot mistake
## a failure for a usable fingerprint.


const RADIUS := 0.028575

const FNV_OFFSET_BASIS: int = -3750763034362895579  # 0xcbf29ce484222325 in i64.
const FNV_PRIME: int = 1099511628211  # 0x100000001b3.


## The fixed rack, in CORE-frame flat triples, as plain f64 values.
static func _fixed_rack() -> Dictionary:
	var flat: Array[float] = [0.25, 0.5625, RADIUS]
	var numbers := PackedInt32Array()
	numbers.append(0)
	for row in 4:
		for col in 4:
			if row == 0 and col == 0:
				continue
			flat.append(0.5 + 0.0625 * float(col))
			flat.append(0.5 + 0.0625 * float(row))
			flat.append(RADIUS)
			numbers.append(numbers.size())
	return {"positions": flat, "numbers": numbers}


## One deterministic shot through the core, returning its hash string.
static func _shot_hash(core, speed: float, contact: Vector2,
		display_positions: PackedVector3Array, numbers: PackedInt32Array) -> String:
	var shot = core.simulate(speed, Vector3(0.0, 0.0, -1.0), contact,
		display_positions, numbers)
	if shot == null or not shot.has_method("get_hash"):
		return ""
	return str(shot.get_hash())


static func compute(core) -> String:
	if core == null or not core.has_method("simulate") \
			or not core.has_method("get_model_version"):
		push_error("DeterminismCanary: no usable PoolCore; canary is unavailable")
		return ""
	var rack: Dictionary = _fixed_rack()
	var positions := RackState.display_from_flat(rack["positions"])
	var numbers: PackedInt32Array = rack["numbers"]
	var hashes: Array[String] = []
	hashes.append(_shot_hash(core, 8.0, Vector2(0.0, 0.0), positions, numbers))
	hashes.append(_shot_hash(core, 5.0, Vector2(0.004, -0.002), positions, numbers))
	hashes.append(_shot_hash(core, 12.0, Vector2(-0.005, 0.003), positions, numbers))
	for h in hashes:
		if h.is_empty():
			push_error("DeterminismCanary: a fixed shot faulted or returned no hash")
			return ""
	return _fnv1a_64(hashes)


static func _fnv1a_64(parts: Array[String]) -> String:
	var acc: int = FNV_OFFSET_BASIS
	for part in parts:
		for byte in part.to_utf8_buffer():
			acc = (acc ^ int(byte)) * FNV_PRIME
	return _hex64(acc)


## Unsigned 64-bit hex without ever materialising a >i64 literal: mask each
## low byte of the (possibly negative) signed accumulator, least significant
## first, and print the bytes in reverse order.
static func _hex64(value: int) -> String:
	var out := ""
	for i in 8:
		var byte: int = (value >> (i * 8)) & 0xff
		out = ("%02x" % [byte]) + out
	return out
