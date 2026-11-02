extends Node3D

## Headless acceptance check of the replay view: the pinned strike resolves to
## the pinned hash, `ShotPlayback.play` replays it on its own clock, the clock
## lands exactly on `get_duration()`, every replayed ball ends within a
## metre-millionth of the core's own final state, and the `path_finished`
## signal reaches this harness through the scene's connection.

const RADIUS := 0.028575  # the rack mirrors the adapter tool's exactly.
const PINNED_HASH := "77cb21802fe44b16"  # 8 m/s, 90 degrees, raised 12.
const EPSILON := 1.0e-6  # m: the replay may miss the core's end by no more.
const CLOCK_STEP := 1.0 / 60.0  # s: one manual step of the clock.
const MAX_STEPS := 10000  # runaway guard for the stepping loop.

var _finish_seen := false  # the path_finished connection has fired.


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


func _strike_params() -> ShotParams:
	# the pinned strike: 8 m/s, a quarter turn, a butt raised 12 degrees.
	var params := ShotParams.new()
	params.speed = 8.0
	params.level_aim_deg = 90.0
	params.elevation_deg = 12.0
	params.contact_x = 0.0
	params.contact_y = -0.4 * RADIUS
	return params


func _run_clock() -> int:
	# manual steps, so the clock we measure is this harness's own feed;
	# -1 says the clamp never tripped within the guard.
	var steps := 0
	while not ($ShotPlayback).is_finished():
		($ShotPlayback).step(CLOCK_STEP)
		steps += 1
		if steps >= MAX_STEPS:
			return -1
	return steps


func _on_path_finished(_shot: PoolShot) -> void:
	_finish_seen = true


func _worst_final_delta(shot: PoolShot, rack: RackState) -> float:
	# the replayed balls against the core's own final state, in metres.
	var final = shot.get_final_state()
	var children = ($ShotPlayback).get_children()
	var worst := 0.0
	for i in rack.numbers.size():
		var laid := (children[i] as Ball).global_transform.origin
		var ended: Vector3 = final["balls"][i]["position"]
		worst = maxf(worst, laid.distance_to(ended))
	return worst


func _ready() -> void:
	var rack := build_rack()
	var params := _strike_params()
	var shot = ($PoolSimulation).resolve(params, rack)
	if shot.get_hash() != PINNED_HASH:
		printerr("playback check: the strike moved from the pinned hash: ",
			shot.get_hash())
		get_tree().quit(1)
		return
	($ShotPlayback).play(shot, rack)
	var steps := _run_clock()
	if steps < 0:
		printerr("playback check: the clock never landed after ", MAX_STEPS,
			" steps")
		get_tree().quit(1)
		return
	var duration = shot.get_duration()
	print("replay clock: ", ($ShotPlayback).get_elapsed(), " s of ", duration,
		" s in ", steps, " steps")
	if not is_equal_approx(($ShotPlayback).get_elapsed(), duration):
		printerr("playback check: the clock missed the duration: ",
			($ShotPlayback).get_elapsed(), " vs ", duration)
		get_tree().quit(1)
		return
	var worst := _worst_final_delta(shot, rack)
	print("worst final-frame delta: ", worst, " m (budget ", EPSILON, ")")
	if not _finish_seen:
		printerr("playback check: path_finished never reached the harness")
		get_tree().quit(1)
		return
	if worst > EPSILON:
		printerr("playback check: the replay drifted ", worst,
			" m off the core's final frame")
		get_tree().quit(1)
		return
	print("playback check: green - ended on duration, balls within budget, ",
		"signal seen")
	get_tree().quit(0)
