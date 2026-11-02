extends Node3D

## Headless characterisation of the adapter.
##
## The test drives the adapter's public API only - the shot goes in as a
## `ShotParams` and a `RackState` and comes back hashed - and asserts the
## card's acceptance: fixed `ShotParams` gives a stable `get_hash()` across
## re-runs, and a broken shot surfaces `get_error()` with its phase instead
## of crashing. Pin the hashes and the golden `c399229b25faae5a` stays green.


const RADIUS := 0.028575  # the rack mirrors scenes/smoke.tscn exactly.
const PINNED_HASH := "77cb21802fe44b16"  # 8 m/s, 90 degrees, raised 12.
const LANE_HASH := "f1cc92702b7599ec"  # 8 m/s, straight into the side pocket.


func build_rack() -> RackState:
	var rack := RackState.new()
	rack.positions.append(Vector3(0.25, RADIUS, -0.5625))
	rack.numbers.append(0)
	rack.rotations.append(Vector3.ZERO)
	for row in 4:
		for col in 4 - row:
			rack.positions.append(Vector3(0.5 + 0.0625 * col, RADIUS,
				-(0.5 + 0.0625 * row + 0.05 * row)))
			rack.numbers.append(rack.positions.size() - 1)
			rack.rotations.append(Vector3.ZERO)
	return rack


## A rack whose cue ball runs straight into the side pocket's shelf.
func build_lane_rack() -> RackState:
	var rack := RackState.new()
	rack.positions.append(Vector3(1.27, RADIUS, 0.5625))
	rack.numbers.append(0)
	rack.rotations.append(Vector3.ZERO)
	for row in 4:
		for col in 4 - row:
			rack.positions.append(Vector3(0.5 + 0.0625 * col, RADIUS,
				-(0.5 + 0.0625 * row + 0.05 * row)))
			rack.numbers.append(rack.positions.size() - 1)
			rack.rotations.append(Vector3.ZERO)
	return rack


## One shot through the adapter's typed door.
func take_shot(rack: RackState, speed: float, aim_deg: float, elevation_deg: float, contact_y: float) -> PoolShot:
	var params := ShotParams.new()
	params.speed = speed
	params.level_aim_deg = aim_deg
	params.elevation_deg = elevation_deg
	params.contact_x = 0.0
	params.contact_y = contact_y
	return ($PoolSimulation).resolve(params, rack)


## A rack where two object balls nearly touch: the pair grinds forever.
func build_jitter_rack() -> RackState:
	var rack := build_rack()
	rack.positions.append(Vector3(0.6, RADIUS, -0.5))
	rack.numbers.append(rack.positions.size() - 1)
	rack.rotations.append(Vector3.ZERO)
	rack.positions.append(Vector3(0.6000000001, RADIUS, -0.5000000001))
	rack.numbers.append(rack.positions.size() - 1)
	rack.rotations.append(Vector3.ZERO)
	return rack


func _ready() -> void:
	var first := take_shot(build_rack(), 8.0, 90.0, 12.0, -0.4 * RADIUS)
	var second := take_shot(build_rack(), 8.0, 90.0, 12.0, -0.4 * RADIUS)
	var first_hash := first.get_hash()
	var second_hash := second.get_hash()
	if first_hash == "" or first_hash != second_hash:
		printerr("adapter test: unstable or empty hash: ", first_hash, " ", second_hash)
		get_tree().quit(1)
	if first_hash != PINNED_HASH:
		printerr("adapter test: hash moved from the pinned value: ", first_hash)
		get_tree().quit(1)
	var outcome = ($PoolSimulation).outcome_of(first)
	print("phase: ", outcome.phase, ", elapsed: ", outcome.elapsed_time)
	print("foul: ", outcome.foul, ", miscue: ", outcome.miscue)
	print("pocketed: ", outcome.pocketed, ", off_table: ", outcome.off_table)
	print("hash: ", first_hash, ", error: ", outcome.error)
	# a shot still sloshing in the pocket shelf at the time cap must surface
	# the settling phase, not a crash:
	var lane := take_shot(build_lane_rack(), 8.0, 90.0, 0.0, 0.0)
	var lane_hash := lane.get_hash()
	if lane_hash != LANE_HASH:
		printerr("adapter test: the lane shot moved: ", lane_hash)
		get_tree().quit(1)
	var lane_outcome = ($PoolSimulation).outcome_of(lane)
	print("lane shot: phase ", lane_outcome.phase, ", elapsed ", lane_outcome.elapsed_time)
	if lane_outcome.phase != "settling":
		printerr("adapter test: no settling phase from the lane shot: ", lane_outcome.phase)
		get_tree().quit(1)
	# the event cap must surface the fault's detail, not a crash:
	var jitter := take_shot(build_jitter_rack(), 4.0, 90.0, 0.0, 0.0)
	var jitter_outcome = ($PoolSimulation).outcome_of(jitter)
	print("jitter shot: phase ", jitter_outcome.phase, ", error ", jitter_outcome.error)
	if jitter_outcome.error == "":
		printerr("adapter test: fault surfaced no error: phase ", jitter_outcome.phase)
		get_tree().quit(1)
	get_tree().quit(0)
