
extends Node3D
class_name AimInput

## AimInput: the mouse turns the line the shot goes along, the way it turns
## the view in a first person game, and F holds the same turn back. Nothing
## here knows another gesture: the HumanShooter hands this scene the drag
## only when the tip, the draw and the raise are not asking for it.

signal aim_turned(turn_degrees: float)

var tuning: CueTuning = CueTuning.new()

var _level_aim_deg := 90.0

func aim_dragged(relative: Vector2, fine: bool) -> void:
	# LOOK_SPEED of a radian per pixel of drag, turned off the way a first
	# person game turns a view: it is the drag, never where the mouse is.
	var scale := tuning.fine_scale if fine else 1.0
	var turned := -relative.x * tuning.look_speed_rad_per_px * scale
	_level_aim_deg = wrapf(_level_aim_deg + rad_to_deg(turned), -180.0, 180.0)
	aim_turned.emit(rad_to_deg(turned))

func get_level_aim_deg() -> float:
	return _level_aim_deg
