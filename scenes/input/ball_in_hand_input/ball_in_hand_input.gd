extends Node3D
class_name BallInHandInput

## Ball-in-hand gesture. It owns one ghost marker and the pointer-to-cloth ray;
## it never starts a stroke. The composer supplies layout, rack and camera,
## enables it only in BallInHand, and listens for the placed position.

signal cue_ball_placed(position: Vector3)

@export var camera: Camera3D
@export var layout: TableLayout
@export var rack: RackState
@export var tolerance: float = 0.0001

var _active := false
var _last_spot := Vector3.ZERO
var _last_legal := false


func _ready() -> void:
	deactivate()


func activate() -> void:
	_active = true
	_last_spot = RackModel.head_spot(layout) if layout != null else Vector3.ZERO
	_last_legal = false
	# The first click may arrive before any motion is reported, so put the
	# ghost under the pointer now instead of leaving it on the head spot.
	if camera != null and layout != null:
		_track_pointer(get_viewport().get_mouse_position())
	_show_marker()
	set_process_unhandled_input(true)


func deactivate() -> void:
	_active = false
	$GhostMarker.visible = false
	set_process_unhandled_input(false)


func is_active() -> bool:
	return _active


func is_last_legal() -> bool:
	return _last_legal


## The public entry a click, an AI or a netcode peer calls. Returns whether
## the spot was accepted; every caller goes through this one legality check.
func place_at(position: Vector3) -> bool:
	if not _active or layout == null:
		return false
	_last_spot = Vector3(position.x, layout.ball_radius, position.z)
	_last_legal = CuePlacement.is_legal(_last_spot, layout, rack, tolerance)
	_show_marker()
	if not _last_legal:
		return false
	cue_ball_placed.emit(_last_spot)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion:
		_track_pointer(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		place_at(_last_spot)


func _track_pointer(screen: Vector2) -> void:
	if camera == null or layout == null:
		return
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if absf(direction.y) < 0.0001:
		return
	var travel := (layout.ball_radius - origin.y) / direction.y
	if travel <= 0.0:
		return
	_last_spot = origin + direction * travel
	_last_legal = CuePlacement.is_legal(_last_spot, layout, rack, tolerance)
	_show_marker()


func _show_marker() -> void:
	$GhostMarker.position = _last_spot
	$GhostMarker.visible = true
	$GhostMarker/Legal.visible = _last_legal
	$GhostMarker/Illegal.visible = not _last_legal
