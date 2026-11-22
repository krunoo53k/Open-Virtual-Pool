extends Node3D

## Focused regression for the rack bookkeeping: a real core shot whose cue is
## pocketed must leave the cue in the model rack (ball-in-hand will respot it),
## carrying the core's final frame, while every other pocketed number still
## leaves the rack. Exit code is the number of failed assertions.

var _fails := 0


func _ready() -> void:
	var view := $Rack as BallRack
	var rack := RackState.new()
	rack.numbers = view.get_numbers()
	rack.positions = view.get_positions()
	rack.rotations = view.get_orientations()
	var other := int(rack.numbers[2])
	var shot: PoolShot = $Simulation.resolve(ShotParams.new(), rack)
	var final: Dictionary = shot.get_final_state()
	var cue_end: Vector3 = final["balls"][0]["position"]
	var spun: PackedVector3Array = shot.sample_rotation(shot.get_duration())
	RackModel.after_shot(shot, [0, other], rack)
	_check(rack.numbers[0] == 0, "cue survives at index 0")
	_check(rack.positions[0].distance_to(cue_end) < 0.000001, "cue keeps the core's final position")
	_check(rack.rotations[0] == spun[0], "cue keeps the core's final rotation")
	_check(not rack.numbers.has(other), "other pocketed ball dropped")
	_check(rack.numbers.size() == 15, "only the cue came back")
	print("rack model: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fail(note)


func _fail(note: String) -> void:
	_fails += 1
	printerr("  FAIL: ", note)
