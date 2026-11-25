extends Node3D
class_name BallInHandInput

## Ball-in-hand gesture. It owns one ghost marker and the pointer-to-cloth ray;
## it never starts a stroke. Holding M drags the cue around and each legal
## spot is previewed, but nothing is placed for the shot until the player
## shoots - the cue can still be moved right up to that moment. The composer
## supplies layout, rack and camera, enables the gesture in BallInHand, and
## listens for the preview and the scripted placement.

signal cue_placement_preview(position: Vector3)
signal cue_ball_placed(position: Vector3)

@export var camera: Camera3D
@export var layout: TableLayout
@export var rack: RackState
@export var tolerance: float = 0.0001

var _active := false
var _last_spot := Vector3.ZERO
var _last_legal := false


func _ready() -> void:
	InputActions.register_defaults()
	deactivate()


func activate() -> void:
	_active = true
	_last_spot = RackModel.head_spot(layout) if layout != null else Vector3.ZERO
	_last_legal = false
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


## The spot the ghost is showing, for a shot that is being committed now.
func get_pending_spot() -> Vector3:
	return _last_spot


## The public entry a scripted player, an AI or a netcode peer calls. Returns
## whether the spot was accepted; every caller goes through this one check.
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
	if event is InputEventMouseMotion and Input.is_action_pressed("ball_in_hand"):
		_track_pointer(event.position)


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
	var previous := _last_spot
	_last_spot = origin + direction * travel
	_last_legal = CuePlacement.is_legal(_last_spot, layout, rack, tolerance)
	_show_marker()
	if _last_legal and _last_spot != previous:
		cue_placement_preview.emit(_last_spot)


func _show_marker() -> void:
	$GhostMarker.position = _last_spot
	$GhostMarker.visible = true
	$GhostMarker/Legal.visible = _last_legal
	$GhostMarker/Illegal.visible = not _last_legal
