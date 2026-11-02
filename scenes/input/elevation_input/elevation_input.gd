
extends Node3D
class_name ElevationInput

## ElevationInput: holding B means the mouse then raises the cue: dragging
# down-screen lifts the butt, which points the shaft DOWN at the ball -
# §12.3 bakes the elevation into the direction, so a positive angle here
# is a positive angle for the core and nothing negates it on the way out.
# A raised cue is what makes a stroke a jump shot. The raise is only asked
# for while the cue is being aimed at: once the cue is being drawn back,
# the mouse's up and down belongs to the draw, and the height keeps the
# value the player left it at.

signal cue_raised(angle_deg: float)

var tuning: CueTuning = CueTuning.new()

var _angle_deg := 0.0

func raise_dragged(relative: Vector2) -> void:
	# 0.1 deg of a degree to a pixel of drag, and the raise is clamped at
	# 60 deg because a bridge cannot follow a shaft steeper than that.
	_angle_deg = clampf(_angle_deg + relative.y * tuning.angle_per_pixel_deg, 0.0, tuning.max_cue_angle_deg)
	cue_raised.emit(_angle_deg)

func get_cue_angle_deg() -> float:
	return _angle_deg
