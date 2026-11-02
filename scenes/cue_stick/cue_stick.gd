extends Node3D
class_name CueStick

## Display of the cue model: it draws where the cue lies from a `CueStickState`
## read back off the shot. The shot's real cue direction never comes through
## here - physics cue direction is made in Rust (§12.3 with `libm`); this
## scene only paints the cue.

const FERRULE_M := 0.06  # m: the white tip sleeve's length.

@export var shaft_length_m := 1.4  # m: tip to butt along the cue axis.


func set_pose(state: CueStickState) -> void:
	var aim := deg_to_rad(state.level_aim_deg)
	# the flat aim mapping shared with the cue camera: degrees from the
	# table's long axis towards the shooter's left, in the cloth plane.
	var flat := Vector3(cos(aim), 0.0, -sin(aim))
	var tilt := deg_to_rad(state.axis_elevation_deg)
	# the axis tilt: a raised butt reads negative and points the cue down.
	var dir := Vector3(cos(tilt) * flat.x, sin(tilt), cos(tilt) * flat.z)
	var tip := state.pivot - dir * state.tip_gap_m
	var butt := tip - dir * shaft_length_m
	# the ferrule hugs the tip, the shaft fills the rest towards the butt.
	_lay($Ferrule, tip, tip - dir * FERRULE_M)
	_lay($Shaft, tip - dir * FERRULE_M, butt)


func _lay(node: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	# unit-height meshes along local +Y, stood on the span and stretched to
	# its length; a zero span draws nothing.
	var span := to - from
	if span.length() < 1.0e-6:
		node.visible = false
		return
	node.visible = true
	var dir := span.normalized()
	var side := Vector3.UP.cross(dir)
	var rot := Quaternion()
	if side.length() < 1.0e-6:
		# straight up or straight down: any perpendicular axis does.
		rot = Quaternion(Vector3(1.0, 0.0, 0.0), 0.0 if dir.y > 0.0 else PI)
	else:
		rot = Quaternion(side.normalized(), acos(clampf(dir.y, -1.0, 1.0)))
	var basis := Basis(rot).scaled(Vector3(1.0, span.length(), 1.0))
	node.transform = Transform3D(basis, (from + to) * 0.5)
