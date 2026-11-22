class_name RackModel
extends RefCounted

## The composer's rack bookkeeping. A RackState stays index-aligned with the
## core's final frame: positions, numbers and rotations move together, and a
## potted or off-table ball leaves all three. The cue (number 0) is the one
## exception: a scratch respots it, so it stays in the rack. No scene here
## simulates anything.

static func after_shot(shot: PoolShot, removed: Array[int], rack: RackState) -> void:
	var final: Dictionary = shot.get_final_state()
	var balls: Array = final["balls"]
	var spun = shot.sample_rotation(shot.get_duration())
	var positions := PackedVector3Array()
	var numbers := PackedInt32Array()
	var rotations := PackedVector3Array()
	for i in balls.size():
		var ball: Dictionary = balls[i]
		var number := int(ball["number"])
		if number != 0 and removed.has(number):
			# A scratched cue is respotted, never removed: dropping it here
			# would make the core strike whichever object ball took index 0.
			continue
		numbers.append(number)
		positions.append(ball["position"])
		rotations.append(spun[i] if i < spun.size() else Vector3.ZERO)
	rack.numbers = numbers
	rack.positions = positions
	rack.rotations = rotations


static func rerack(view: BallRack, rack: RackState) -> void:
	# A re-rack ruling starts from the rack's own seeded layout, not from the
	# shot's final frame: handing that frame on leaves potted balls missing.
	view.rebuild()
	rack.numbers = view.get_numbers()
	rack.positions = view.get_positions()
	rack.rotations = view.get_orientations()


static func head_spot(layout: TableLayout) -> Vector3:
	return Vector3(layout.length * 0.25, layout.ball_radius, -layout.width * 0.5)


static func respot_cue(rack: RackState, spot: Vector3) -> void:
	var index := rack.numbers.find(0)
	if index < 0 or index >= rack.positions.size():
		return
	var positions := PackedVector3Array(rack.positions)
	positions[index] = spot
	rack.positions = positions
	if index < rack.rotations.size():
		var rotations := PackedVector3Array(rack.rotations)
		rotations[index] = Vector3.ZERO
		rack.rotations = rotations
