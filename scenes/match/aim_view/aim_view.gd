extends Node3D
class_name AimView

## Composes the two aim views from #5 and feeds them one typed hand-off from
## the active HumanShooter. The adapter's preview and ghost answer every
## number the views draw, so the picture cannot drift from the strike.

signal view_state_changed(state: AimViewState)

@export var simulation: PoolSimulation

var _rack: RackState
var _shooter: HumanShooter
var _state: AimViewState
var _signature := ""


func _process(_delta: float) -> void:
	# Leaf gestures are continuous (the draw in particular), so compare the
	# typed snapshot each frame instead of trusting signal ordering.
	if _shooter == null:
		return
	var state := AimStateReader.read(_shooter)
	var signature := "%f|%f|%f|%f|%f|%f" % [state.level_aim_deg, state.elevation_deg,
		state.english.x, state.english.y, state.pull_m, state.speed_m_s]
	if signature != _signature:
		_signature = signature
		_refresh()


func bind(rack: RackState) -> void:
	_rack = rack


func follow(shooter: HumanShooter) -> void:
	if _shooter != null and _shooter.aim_state_changed.is_connected(_on_state_changed):
		_shooter.aim_state_changed.disconnect(_on_state_changed)
	_shooter = shooter
	if _shooter != null:
		_shooter.aim_state_changed.connect(_on_state_changed)
	_refresh()


func set_view_visible(value: bool) -> void:
	$CueStick.visible = value
	$AimPreview.visible = value


func get_cue_position() -> Vector3:
	if _rack != null and not _rack.positions.is_empty():
		return _rack.positions[0]
	return Vector3.ZERO


func get_state() -> AimViewState:
	return _state


func _on_state_changed() -> void:
	_refresh()


func _refresh() -> void:
	if _shooter == null or _rack == null or _rack.positions.is_empty():
		return
	var state := AimStateReader.read(_shooter)
	var params := ShotParams.new()
	params.speed = maxf(state.speed_m_s, 2.0)
	params.level_aim_deg = state.level_aim_deg
	params.elevation_deg = state.elevation_deg
	params.contact_x = state.english.x
	params.contact_y = state.english.y
	var cue := get_cue_position()
	var preview: ShotPreview = simulation.preview_of(params)
	var ghost: ShotGhost = simulation.ghost_of(params, _rack)
	var pose := CueStickState.new()
	pose.pivot = cue
	pose.level_aim_deg = state.level_aim_deg
	pose.axis_elevation_deg = preview.elevation_deg
	pose.tip_gap_m = simulation.layout.ball_radius + state.pull_m
	pose.contact = state.english
	pose.ball_radius_m = simulation.layout.ball_radius
	$CueStick.set_pose(pose)
	$AimPreview.show_stretch(cue, preview, ghost)
	_state = state
	view_state_changed.emit(state)
