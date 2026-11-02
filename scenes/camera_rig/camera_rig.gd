extends Node3D
class_name CameraRig

## The eye the game shows. Two cameras live here and a toggle flips between
## them: the cue camera follows behind the ball along the flat aim, the table
## camera keeps the whole cloth. Both are display views; nothing here decides
## shot facts. `camera_toggle` is bound by InputActions (key C); where an
## action is left unregistered the press is simply not seen, and the rig
## keeps its table overview.

@export var cue_orbit_distance := 0.9  # m: the cue eye behind the ball.
@export var cue_orbit_height := 0.38  # m: the cue eye above the cloth.
@export var overview_height := 2.2  # m: the table camera's height.
@export var table_centre := Vector3(1.27, 0.0, 0.0)  # m: the table's middle.

var _on_cue := false  # which eye is showing now (the table by default).


func _ready() -> void:
	_table_view()


func _table_view() -> void:
	$TableCamera.global_position = table_centre + Vector3(0.0, overview_height, 0.0)
	$TableCamera.look_at(table_centre)
	$TableCamera.current = true
	$CueCamera.current = false
	_on_cue = false


func _cue_view() -> void:
	$CueCamera.current = true
	$TableCamera.current = false
	_on_cue = true


func follow_aim(cue_position: Vector3, level_aim_deg: float) -> void:
	# same flat mapping as the cue view: degrees from the long axis towards
	# the shooter's left. it aims the model camera, never a physics shot.
	var aim := deg_to_rad(level_aim_deg)
	var flat := Vector3(cos(aim), 0.0, -sin(aim))
	var eye := cue_position - flat * cue_orbit_distance + Vector3(0.0, cue_orbit_height, 0.0)
	$CueCamera.global_position = eye
	$CueCamera.look_at(cue_position)


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("camera_toggle"):
		_flip()


func _flip() -> void:
	if _on_cue:
		_table_view()
	else:
		_cue_view()
