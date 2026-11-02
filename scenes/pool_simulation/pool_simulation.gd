extends Node3D

## The one adapter that wraps the GDExtension.
##
## Exactly one scene touches `PoolCore` for simulation: it owns the typed
## boundary - shots go in as `ShotParams` and a `RackState` in Godot's frame,
## paths and outcomes come back as `PoolShot` and `ShotOutcome` - and every
## frame and sign conversion lives on its two sides only: this call passes
## player-intent numbers straight through, and `pool-godot/src/frame.rs`
## converts. Nothing else in the tree may construct a `PoolCore` or read
## the core's raw Dictionary.
##
## The direction of every shot comes from Rust (`make_cue_direction`, §12.3
## with §11.4's `libm`): GDScript never calls `sin`/`cos` to build a
## replayable direction, so a pin stored as degrees replays the same
## everywhere.


var core  # the extension instance this adapter owns.
var layout  # the table's numbers, built once from the core's geometry.


func _ready() -> void:
		core = PoolCore.new()
		layout = TableLayout.build(core.get_table_geometry())
		print("adapter: core model ", core.get_model_version())

## Resolve one stroke: the whole shot in one call, path included.
func resolve(params: ShotParams, rack: RackState) -> PoolShot:
	var direction = core.make_cue_direction(params.level_aim_deg, params.elevation_deg)
	var contact := Vector2(params.contact_x, params.contact_y)
	# empty rotations means every ball starts at identity (§11.2's hand-off);
	# the rotation variant is the only call, so spin carry is always wired.
	return core.simulate_with_rotations(params.speed, direction, contact,
		rack.positions, rack.numbers, rack.rotations)


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
