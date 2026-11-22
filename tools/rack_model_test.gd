extends Node3D

## Focused regression for the rack bookkeeping: a real core shot whose cue is
## pocketed must leave the cue in the model rack at its pre-shot spot, clear of
## spin, while every other pocketed number still leaves the rack. Exit code is
## the number of failed assertions.

var _fails := 0


func _ready() -> void:
	var view := $Rack as BallRack
	var rack := RackState.new()
	rack.numbers = view.get_numbers()
	rack.positions = view.get_positions()
	rack.rotations = view.get_orientations()
	var cue_before: Vector3 = rack.positions[0]
	var other := int(rack.numbers[2])
	var shot: PoolShot = $Simulation.resolve(ShotParams.new(), rack)
	RackModel.after_shot(shot, [0, other], rack)
	_check(rack.numbers[0] == 0, "cue survives at index 0")
	_check(rack.positions[0].distance_to(cue_before) < 0.000001, "pre-shot cue spot kept")
	_check(rack.rotations[0] == Vector3.ZERO, "cue rotation cleared")
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
