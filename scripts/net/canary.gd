class_name DeterminismCanary
extends RefCounted

## Provisional client-side determinism canary.
##
## The loaded bridge has no engine canary API and no `simulate_from_intent_f64`
## (model version "1.9"), so until the engine ships one we compute the same
## fingerprint the server is asked to compute: run THREE fixed shots through a
## real `PoolCore`, take each `PoolShot.get_hash()` string, and fold the three
## strings into one 64-bit hash.
##
## ---------------------------------------------------------------------------
## EXACT RECIPE (the future server MUST match this byte for byte)
## ---------------------------------------------------------------------------
## 1. Build one fixed rack (the smoke rack) in CORE-frame flat triples:
##      radius = 0.028575,
##      cue    = (0.25, 0.5625, radius), number 0,
##      object i = (0.5 + 0.0625*col, 0.5 + 0.0625*row, radius),
##                 for row = 0..3, col = 0..3, except (row, col) = (0, 0),
##                 numbered 1..15 in row-major order.
##    Convert to the legacy Godot-frame vectors with
##    `RackState.display_from_flat` exactly once, then call
##    `core.simulate(speed, direction, contact, positions, numbers)`.
## 2. The three shots, in this order, all with direction = (0, 0, -1):
##      A: speed 8.0,  contact (0.0,  0.0)
##      B: speed 5.0,  contact (0.004, -0.002)
##      C: speed 12.0, contact (-0.005, 0.003)
##    No trig, no normalisation, no randomness — the direction is a literal so
##    both sides feed identical f64 values into the core.
## 3. Let hA, hB, hC be the three `get_hash()` strings (decimal/hex text).
##    Concatenate them with NO separator into one UTF-8 byte string:
##    `hA + hB + hC`.
## 4. FNV-1a 64-bit over that byte string:
##      offset basis = 0xcbf29ce484222325 (stored as signed i64
##                     -3750763034362895579),
##      prime        = 0x100000001b3     (1099511628211),
##      for each byte b: acc = (acc XOR b) * prime, wrapping mod 2^64
##      (GDScript's 64-bit int arithmetic already wraps).
## 5. Emit the final unsigned 64-bit `acc` as exactly 16 lowercase hex digits,
##    most significant byte first. That string is the `canary` field of HELLO.
##
## Any fault (missing core, faulted shot, empty hash) returns "" after a loud
## push_error: a pure-logic harness must not crash, but a bad canary must be
## impossible to mistake for a valid one.

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
