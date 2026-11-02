extends Node3D
class_name AimPreview

## Draws the stretch the adapter's display ray answered with: the aim line,
## the ghost ball at first touch, the marker on the touched ball and the
## leave arrow of the same strike. Display only: it never touches the core
## or physics, and every number arrives through `show_stretch`.

const LEAVE_ARROW_M := 0.25  # m: how long a leave arrow is drawn.


func _ready() -> void:
	# an empty view claims nothing until a stretch is shown.
	$GhostLine.visible = false
	$LeaveArrow.visible = false
	$GhostBall.visible = false
	$HitMarker.visible = false


func show_stretch(cue_position: Vector3, preview: ShotPreview, ghost: ShotGhost) -> void:
	# the line stops at the ghost or the near rail, both already answered.
	_lay($GhostLine, cue_position, ghost.line_end)
	$GhostBall.visible = ghost.has_hit
	$GhostBall.global_position = ghost.ghost_position
	$HitMarker.visible = ghost.has_hit
	$HitMarker.global_position = ghost.hit_position
	_lay_arrow(cue_position, preview.velocity)


func _lay_arrow(cue_position: Vector3, velocity: Vector3) -> void:
	if velocity.length() < 1.0e-6:
		# a leave that went nowhere shows no direction.
		$LeaveArrow.visible = false
		return
	$LeaveArrow.visible = true
	var leave := velocity.normalized()
	_lay($LeaveArrow, cue_position, cue_position + leave * LEAVE_ARROW_M)


func _lay(node: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	# the slim cylinders are unit-height meshes along local +Y: stand the
	# axis on the span and scale it to the span's length.
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
