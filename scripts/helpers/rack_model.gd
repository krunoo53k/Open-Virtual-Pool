class_name RackModel
extends RefCounted

## The composer's rack bookkeeping. A RackState stays index-aligned with the
## core's final frame: positions, numbers and rotations move together, and a
## potted or off-table ball leaves all three. No scene here simulates anything.

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
		if removed.has(number):
			continue
		numbers.append(number)
		positions.append(ball["position"])
		rotations.append(spun[i] if i < spun.size() else Vector3.ZERO)
	rack.numbers = numbers
	rack.positions = positions
	rack.rotations = rotations


static func head_spot(layout: TableLayout) -> Vector3:
	return Vector3(layout.length * 0.25, layout.ball_radius, -layout.width * 0.5)


static func respot_cue(rack: RackState, spot: Vector3) -> void:
	if rack.positions.is_empty():
		return
	var positions := PackedVector3Array(rack.positions)
	var rotations := PackedVector3Array(rack.rotations)
	positions[0] = spot
	if not rotations.is_empty():
		rotations[0] = Vector3.ZERO
	rack.positions = positions
	rack.rotations = rotations
