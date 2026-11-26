class_name CuePlacement
extends RefCounted

## Pure geometry for BCA ball-in-hand: the cue may go anywhere on the cloth,
## as long as the whole ball lies inside the bed and clear of every other
## ball. No scene, input state or rule is read here.

const DEFAULT_TOLERANCE := 0.0001

## `rack.numbers` identifies the cue (number 0), which never blocks itself.
static func is_legal(position: Vector3, layout: TableLayout, rack: RackState,
		tolerance: float = DEFAULT_TOLERANCE) -> bool:
	if layout == null:
		return false
	var r := layout.ball_radius
	if position.x < r or position.x > layout.length - r:
		return false
	if position.z < -layout.width + r or position.z > -r:
		return false
	if rack == null:
		return true
	# `positions` holds three floats per ball; the ball count lives in `numbers`.
	for i in rack.numbers.size():
		if int(rack.numbers[i]) == 0:
			continue
		var other := rack.get_position(i)
		var flat := Vector2(position.x - other.x, position.z - other.z)
		if flat.length() < 2.0 * r - tolerance:
			return false
	return true
