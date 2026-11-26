extends Node3D

## Focused regression for the rack bookkeeping: a scratched cue is respotted on
## the bed, whether the core froze it in a pocket or off the table in mid-air,
## while every other pocketed number still leaves the rack. Exit code is the
## number of failed assertions.

var _fails := 0


func _ready() -> void:
	var sim: PoolSimulation = $Simulation
	var layout: TableLayout = sim.layout
	var view := $Rack as BallRack
	var rack := RackState.new()
	rack.numbers = view.get_numbers()
	rack.positions = RackState.flat_from_display(view.get_positions())
	rack.rotations = RackState.flat_from_display(view.get_orientations())
	var other := int(rack.numbers[2])
	var shot: PoolShot = sim.resolve(ShotParams.new(), rack)
	RackModel.after_shot(shot, [0, other], rack, layout)
	_check(rack.numbers[0] == 0, "cue survives at index 0")
	_check(rack.get_position(0) == RackModel.head_spot(layout), "scratched cue respots at the head spot")
	_check(rack.get_rotation(0) == Vector3.ZERO, "respotted cue starts unspun")
	_check(not rack.numbers.has(other), "other pocketed ball dropped")
	_check(rack.numbers.size() == 15, "only the cue came back")
	_check_mid_air_scratch(sim, layout)
	print("rack model: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _check_mid_air_scratch(sim: PoolSimulation, layout: TableLayout) -> void:
	var params := ShotParams.new()
	params.speed = 8.0
	params.elevation_deg = 20.0  # a jump that carries the cue over a rail
	var jump := RackState.new()
	jump.add_ball(0, Vector3(0.4, layout.ball_radius, -0.6))
	jump.add_ball(1, Vector3(0.8, layout.ball_radius, -0.6))
	var shot: PoolShot = sim.resolve(params, jump)
	var final: Dictionary = shot.get_final_state()
	var end: Vector3 = final["balls"][0]["position"]
	_check(end.y > layout.ball_radius + 0.01, "the jump really did take the cue off the bed")
	RackModel.after_shot(shot, [0], jump, layout)
	_check(jump.numbers.has(0), "an off-table cue survives in the rack")
	_check(jump.get_position(0) == RackModel.head_spot(layout), "off-table cue respots at the head spot")
	_check(absf(jump.get_position(0).y - layout.ball_radius) < 0.000001,
		"off-table cue respots on the bed")
	_check(jump.get_rotation(0) == Vector3.ZERO, "off-table cue starts unspun")


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fail(note)


func _fail(note: String) -> void:
	_fails += 1
	printerr("  FAIL: ", note)
