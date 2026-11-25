extends Node3D
class_name BallInHandInput

## Ball-in-hand gesture. It owns one ghost marker and previews the cue spot;
## it never starts a stroke. The table eye uses the pointer-to-cloth ray,
## which is precise from above; the close cue eye would turn a pixel into a
## metre, so it uses a fixed camera-relative drag instead. Holding M drags the
## cue and locks camera rotation; with M up the shooter turns the aim and the
## cue camera orbits. Nothing is locked in until the stroke starts.

signal cue_placement_preview(position: Vector3)
signal cue_ball_placed(position: Vector3)

@export var camera: Camera3D
@export var layout: TableLayout
@export var rack: RackState
@export var tolerance: float = 0.0001
@export var cue_drag_m_per_px := 0.004

@export var cue_view: bool = false  # set by the composer when the eye changes

var _active := false
var _last_spot := Vector3.ZERO
var _last_legal_spot := Vector3.ZERO
var _last_legal := false
var _pointer := Vector2.ZERO


func _ready() -> void:
	InputActions.register_defaults()
	deactivate()


func activate() -> void:
	_active = true
	_last_spot = RackModel.head_spot(layout) if layout != null else Vector3.ZERO
	_last_legal_spot = _last_spot
	_last_legal = false
	_pointer = get_viewport().get_visible_rect().size * 0.5
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
	_last_legal_spot = _last_spot
	cue_ball_placed.emit(_last_spot)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not event is InputEventMouseMotion:
		return
	var motion := event as InputEventMouseMotion
	if not Input.is_action_pressed("ball_in_hand"):
		return
	if cue_view:
		_track_drag(motion.relative)
		return
	var screen := motion.position
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# A grabbed cursor reports only relative motion, so follow it with a
		# virtual pointer; a free cursor's own screen position is the truth.
		if motion.relative != Vector2.ZERO:
			var size := get_viewport().get_visible_rect().size
			_pointer = (_pointer + motion.relative).clamp(Vector2.ZERO, size)
		screen = _pointer
	_track_pointer(screen)


func _track_drag(relative: Vector2) -> void:
	if camera == null or layout == null:
		return
	var basis := camera.global_transform.basis
	# Flatten the eye so a screen drag stays a steady walk on the cloth.
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var move := (right * relative.x - forward * relative.y) * cue_drag_m_per_px
	# Walk from the last legal spot, not from a red ghost over a ball.
	var spot := _last_legal_spot + move
	spot.x = clampf(spot.x, layout.ball_radius, layout.length - layout.ball_radius)
	spot.z = clampf(spot.z, -layout.width + layout.ball_radius, -layout.ball_radius)
	_accept(spot)


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
	_accept(origin + direction * travel)


## Both schemes end here: one legality check, one marker, one preview signal.
func _accept(spot: Vector3) -> void:
	var previous := _last_legal_spot
	_last_spot = spot
	_last_legal = CuePlacement.is_legal(spot, layout, rack, tolerance)
	if _last_legal:
		_last_legal_spot = spot
	_show_marker()
	if _last_legal and _last_legal_spot != previous:
		cue_placement_preview.emit(_last_legal_spot)


func _show_marker() -> void:
	$GhostMarker.position = _last_spot
	$GhostMarker.visible = true
	$GhostMarker/Legal.visible = _last_legal
	$GhostMarker/Illegal.visible = not _last_legal
