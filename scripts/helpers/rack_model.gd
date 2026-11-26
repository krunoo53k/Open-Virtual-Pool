class_name RackModel
extends RefCounted

## The composer's rack bookkeeping. A RackState stays index-aligned with the
## core's final frame: positions, numbers and rotations move together, and a
## potted or off-table ball leaves all three. The cue (number 0) is the one
## exception: a scratch respots it, so it stays in the rack. No scene here
## simulates anything.
##
## RackState stores flat CORE-frame triples; everything that comes from a view
## or from the core's Godot-frame read-back is converted at the write end with
## `RackState.core_triple`, never by copying Vector3s into the flat arrays.

static func after_shot(shot: PoolShot, removed: Array[int], rack: RackState,
		layout: TableLayout) -> void:
	var final: Dictionary = shot.get_final_state()
	var balls: Array = final["balls"]
	var spun = shot.sample_rotation(shot.get_duration())
	var numbers := PackedInt32Array()
	var positions: Array[float] = []
	var rotations: Array[float] = []
	for i in balls.size():
		var ball: Dictionary = balls[i]
		var number := int(ball["number"])
		if number != 0 and removed.has(number):
			continue
		numbers.append(number)
		if number == 0 and removed.has(0):
			# A scratched cue is respotted, never left where the core froze it:
			# a ball taken out of play off the table can stop in mid-air.
			positions.append_array(RackState.core_triple(head_spot(layout)))
			rotations.append_array(RackState.core_triple(Vector3.ZERO))
			continue
		var position: Vector3 = ball["position"]
		# A ball still resting on the cloth rests at exactly one radius.
		# The core's read-back is in Godot's frame, so convert into the rack's
		# core frame before storing.
		var resting := Vector3(position.x, layout.ball_radius, position.z)
		positions.append_array(RackState.core_triple(resting))
		rotations.append_array(RackState.core_triple(
			spun[i] if i < spun.size() else Vector3.ZERO))
	rack.numbers = numbers
	rack.positions = positions
	rack.rotations = rotations


static func rerack(view: BallRack, rack: RackState) -> void:
	# A re-rack ruling starts from the rack's own seeded layout, not from the
	# shot's final frame: handing that frame on leaves potted balls missing.
	view.rebuild()
	rack.numbers = view.get_numbers()
	rack.positions = RackState.flat_from_display(view.get_positions())
	rack.rotations = RackState.flat_from_display(view.get_orientations())


## The head spot in Godot's display frame (x along, y up, z across).
static func head_spot(layout: TableLayout) -> Vector3:
	return Vector3(layout.length * 0.25, layout.ball_radius, -layout.width * 0.5)


## `spot` arrives from ball-in-hand in Godot's frame; the setter converts.
static func respot_cue(rack: RackState, spot: Vector3) -> void:
	var index := rack.numbers.find(0)
	if index < 0:
		return
	rack.set_position(index, spot)
	rack.set_rotation(index, Vector3.ZERO)
