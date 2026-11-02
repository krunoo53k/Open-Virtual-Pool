extends Node3D

## Headless acceptance check of the aim overlay: the display ray's ghost must
## sit where the core's own path says the cue ball first touches - same
## strike, two answers, no drift - and `AimPreview` must then put its ghost
## marker exactly where the ray answered.

const RADIUS := 0.028575  # m: the core's ball radius, so 2R is contact.
const LAYBACK := 1.40  # m along the aim to the object ball.
const CUT_OFFSET := 0.040  # m across the aim: a cut, under the 2R full ball.
const DRIFT_EPS := 1.0e-6  # m: ray answer against the core's own contact.

const CUE_X := 0.90  # m: the cue sits mid-table along the length.
const CENTER_Z := -0.635  # m: Godot's centreline; the core maps y = -z.


func _cue_touch_drift(shot: PoolShot, ghost: ShotGhost) -> float:
	# every event printed so the cue's contact can be picked robustly;
	# kind "ball-ball" with index 0 is the cue meeting a ball.
	var events = shot.get_events()
	var first := -1.0
	for e in events:
		print("event: ", e)
		if String(e["kind"]) == "ball-ball" and (int(e["a"]) == 0 or int(e["b"]) == 0):
			first = float(e["time"])
			break
	if first < 0.0:
		printerr("ghost check: no cue-to-ball contact event in the shot")
		return -1.0
	var at = shot.sample(first)
	return (at[0] - ghost.ghost_position).length()


func _build_cut_rack(cue: Vector3, leave: Vector3, perp: Vector3) -> RackState:
	var rack := RackState.new()
	rack.positions.append(cue)
	rack.numbers.append(0)
	rack.rotations.append(Vector3.ZERO)
	rack.positions.append(cue + leave * LAYBACK + perp * CUT_OFFSET)
	rack.numbers.append(1)
	rack.rotations.append(Vector3.ZERO)
	return rack


func _strike_params() -> ShotParams:
	# a slow straight strike up the table's centreline.
	var params := ShotParams.new()
	params.speed = 3.0
	params.level_aim_deg = 0.0
	params.elevation_deg = 0.0
	params.contact_x = 0.0
	params.contact_y = 0.0
	return params


func _leave_in_plane(preview: ShotPreview) -> Vector3:
	# the flat leave the core promises; zero when the strike left nowhere.
	var leave := Vector3(preview.velocity.x, 0.0, preview.velocity.z)
	if leave.length() < 1.0e-6:
		return Vector3.ZERO
	return leave.normalized()


func _show_and_place(cue: Vector3, preview: ShotPreview, ghost: ShotGhost) -> bool:
	# the overlay then the marker: a faithful view put its ghost ball exactly
	# where the ray answered, and showed it.
	($AimPreview).show_stretch(cue, preview, ghost)
	var marker := ($AimPreview).get_node("GhostBall") as Node3D
	var faithful := marker.visible and marker.global_position.is_equal_approx(ghost.ghost_position)
	print("overlay marker at ", marker.global_position, ", visible: ", marker.visible)
	return faithful


func _ready() -> void:
	var params := _strike_params()
	# the preview first: the rack is built along the strike's own leave.
	var preview = ($PoolSimulation).preview_of(params)
	var leave := _leave_in_plane(preview)
	if leave.length() < 1.0e-6:
		printerr("ghost check: the preview left nowhere to build against")
		get_tree().quit(1)
		return
	var cue := Vector3(CUE_X, RADIUS, CENTER_Z)
	var perp := Vector3(-leave.z, 0.0, leave.x)
	var rack := _build_cut_rack(cue, leave, perp)
	var ghost = ($PoolSimulation).ghost_of(params, rack)
	if not ghost.has_hit or ghost.hit_ball_number != 1:
		printerr("ghost check: the stretch missed or hit the wrong ball")
		get_tree().quit(1)
		return
	print("ghost answer: touch at ", ghost.ghost_position)
	var shot = ($PoolSimulation).resolve(params, rack)
	if shot.get_error() != "":
		printerr("ghost check: the shot faulted: ", shot.get_error())
		get_tree().quit(1)
		return
	var drift := _cue_touch_drift(shot, ghost)
	if drift < 0.0:
		get_tree().quit(1)
		return
	print("cue touch drift: ", drift, " m (budget ", DRIFT_EPS, ")")
	if drift > DRIFT_EPS:
		printerr("ghost check: the ray drifted ", drift,
			" m off the core's own contact")
		get_tree().quit(1)
		return
	if not _show_and_place(cue, preview, ghost):
		printerr("ghost check: the overlay did not faithfully place the marker")
		get_tree().quit(1)
		return
	get_tree().quit(0)
