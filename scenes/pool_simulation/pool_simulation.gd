class_name PoolSimulation extends Node3D

## The one adapter that wraps the GDExtension.
##
## Exactly one scene touches `PoolCore` for simulation: it owns the typed
## boundary - shots go in as `ShotParams` and a `RackState` in the CORE frame,
## paths and outcomes come back as `PoolShot` and `ShotOutcome` - and every
## frame and sign conversion lives on its two sides only.
##
## C1 stage 1 keeps the old f32 bridge: this call converts the rack's flat
## core-frame triples back to Godot-frame `PackedVector3Array`s for Rust's
## `frame.rs`. Stage 2 replaces that single call with `simulate_from_intent_f64`
## once the engine agent delivers it (flip `USE_F64_INTENT` below); no caller
## outside this file changes. The hotseat path keeps the legacy call until its
## documented sunset date.
##
## The direction of every shot comes from Rust (`make_cue_direction`, §12.3
## with §11.4's `libm`): GDScript never calls `sin`/`cos` to build a
## replayable direction, so a pin stored as degrees replays the same
## everywhere.

## Stage 2 switch. The engine has not shipped the f64 intent entry point yet;
## the seam below is ready but stays off so hotseat hashes do not move.
const USE_F64_INTENT := false


var core  # the extension instance this adapter owns.
var layout  # the table's numbers, built once from the core's geometry.


func _ready() -> void:
		core = PoolCore.new()
		layout = TableLayout.build(core.get_table_geometry())
		print("adapter: core model ", core.get_model_version())


## Resolve one stroke: the whole shot in one call, path included.
##
## Stage 1: RackState stores flat f64 triples in the CORE frame; the legacy
## `simulate_with_rotations` wants Godot-frame PackedVector3Arrays. The
## inverse/display transform happens here and nowhere else.
func resolve(params: ShotParams, rack: RackState) -> PoolShot:
	var direction = core.make_cue_direction(params.level_aim_deg, params.elevation_deg)
	var contact := Vector2(params.contact_x, params.contact_y)
	# empty rotations means every ball starts at identity (§11.2's hand-off);
	# the rotation variant is the only call, so spin carry is always wired.
	return core.simulate_with_rotations(params.speed, direction, contact,
		RackState.display_from_flat(rack.positions), rack.numbers,
		RackState.display_from_flat(rack.rotations))


## Resolve a shot from the numbers that were actually put on the wire.
##
## Online prediction MUST use this entry, not `resolve()`: the shooter sends
## JSON and then simulates the parsed numbers, so a float that serialization
## shortened cannot make the client and server disagree. Both dictionaries are
## plain JSON values (arrays of f64 and ints), never the caller's live locals.
##
## Stage 1 rebuilds typed objects from those values and still goes through
## `resolve()`; the f32 bridge is itself a loss point, which is precisely why
## stage 2 swaps in the engine's `simulate_from_intent_f64` (the branch below
## is written now and activated by flipping `USE_F64_INTENT`).
func resolve_serialized(params: Dictionary, rack_data: Dictionary) -> PoolShot:
	if USE_F64_INTENT and core.has_method("simulate_from_intent_f64"):
		# Stage 2: one Rust-only call, flat core-frame f64 arrays all the way.
		# Signature matches the engine's delivered `PoolCore` method:
		# (speed, aim, elevation, contact_x, contact_y,
		#  PackedFloat64Array positions, PackedInt32Array numbers,
		#  PackedFloat64Array rotations).
		var positions := _packed_floats(rack_data["positions"])
		var rotations := _packed_floats(rack_data.get("rotations", []))
		return core.simulate_from_intent_f64(
			float(params["speed"]), float(params["level_aim_deg"]),
			float(params["elevation_deg"]), float(params["contact_x"]),
			float(params["contact_y"]), positions, _ints(rack_data["numbers"]),
			rotations)
	var typed := ShotParams.new()
	typed.speed = float(params["speed"])
	typed.level_aim_deg = float(params["level_aim_deg"])
	typed.elevation_deg = float(params["elevation_deg"])
	typed.contact_x = float(params["contact_x"])
	typed.contact_y = float(params["contact_y"])
	var rack := RackState.new()
	rack.positions = _floats(rack_data["positions"])
	rack.numbers = _ints(rack_data["numbers"])
	rack.rotations = _floats(rack_data.get("rotations", []))
	return resolve(typed, rack)


## Wire shapes. `params_dict` carries exactly the six scalar intent fields;
## `rack_dict` carries the flat CORE-frame arrays. Neither applies a display
## transform. Online prediction round-trips these through full-precision JSON
## and hands the parsed values back to `resolve_serialized`.
static func params_dict(params: ShotParams) -> Dictionary:
	return {
		"speed": params.speed,
		"level_aim_deg": params.level_aim_deg,
		"elevation_deg": params.elevation_deg,
		"contact_x": params.contact_x,
		"contact_y": params.contact_y,
		"called_pocket": params.called_pocket,
	}


static func rack_dict(rack: RackState) -> Dictionary:
	return {
		"positions": rack.positions.duplicate(),
		"numbers": Array(rack.numbers),
		"rotations": rack.rotations.duplicate(),
	}


static func _packed_floats(value: Variant) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for item in value:
		out.append(float(item))
	return out


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


## Tell what a resolved shot ended in, the way the game reads it.
func outcome_of(shot: PoolShot) -> ShotOutcome:
	var state := shot.get_final_state()
	var outcome := ShotOutcome.new()
	# a faulted shot still gets an outcome: phase and error carry the fault.
	outcome.elapsed_time = float(state["elapsed_time"])
	outcome.phase = String(state["phase"])
	# a miscue is always a foul, the core already says so (§6.3).
	outcome.foul = bool(state["foul"])
	outcome.miscue = bool(state["miscue"])
	# the fault's detail, empty when the shot ran.
	outcome.error = shot.get_error()
	# pocketed and off-table lists are ball numbers, not indices.
	for ball in state["balls"]:
		if bool(ball["pocketed"]):
			outcome.pocketed.append(int(ball["number"]))
		if bool(ball["off_table"]):
			# a ball that left the bed is a foul the core already flagged (§10.1).
			# the number keeps a record of it too.
			outcome.off_table.append(int(ball["number"]))
	return outcome


## The shot's events, typed and in ball-number terms. The only index -> number
## mapping sits here, behind the adapter's door, so the rules never see indices.
func events_of(shot: PoolShot, rack: RackState) -> Array[ShotEvent]:
	return ShotEvents.from_core(shot.get_events(), rack)


## What the same strike would do, short of running it.
func preview_of(params: ShotParams) -> ShotPreview:
	var direction = core.make_cue_direction(params.level_aim_deg, params.elevation_deg)
	var seen = core.preview_cue_strike(params.speed, direction,
		# player-intent tip offset, same as resolve: signs live in Rust.
		(Vector2(params.contact_x, params.contact_y)))
	var preview := ShotPreview.new()
	# every number is the core's own read-back; nothing is re-derived here.
	preview.velocity = seen["velocity"]
	preview.squirt_deg = float(seen["squirt_deg"])
	preview.squirt_sign = float(seen["squirt_sign"])
	preview.miscue = bool(seen["miscue"])
	preview.impact_parameter = float(seen["impact_parameter"])
	# a raised butt points down at the ball: negative here (§12.3's sign).
	preview.elevation_deg = float(seen["elevation_deg"])
	return preview


## Where the cue ball would first touch along the stretch, and where the
## aim line ends: the display ray's answer, typed. The one place a ray
## test sits stays behind the adapter's door: views display this and never
## derive it.
func ghost_of(params: ShotParams, rack: RackState) -> ShotGhost:
	var preview := preview_of(params)
	return DisplayRay.stretch_of(rack, preview, layout)

## The loaded bridge's model version, so a shot log says which core ran it.
func model_version() -> float:
	return float(core.get_model_version())


## How far the tip may leave the centre before the shot miscues (§6.3).
## The human shooter's english gesture clamps its drag to this disc;
## the number is the core's, so the limit stays the same everywhere.
func miscue_limit() -> float:
	return core.get_miscue_limit()
