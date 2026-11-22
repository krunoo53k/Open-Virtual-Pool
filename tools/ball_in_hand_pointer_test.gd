extends Node3D

## Headless check of BallInHandInput's pointer-to-cloth ray. The legality
## harness drives place_at directly; this one injects real mouse-motion events
## and checks that the ghost follows the ray onto the cloth. Exit code is the
## number of failed assertions.

var _fails := 0


func _ready() -> void:
	var layout := TableLayout.new()
	var camera := $Camera as Camera3D
	camera.position = Vector3(layout.length * 0.5, 2.0, -layout.width * 0.5)
	camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)  # straight down, screen right is +x
	var input := $BallInHandInput as BallInHandInput
	input.layout = layout
	input.camera = camera
	input.activate()
	var centre := get_viewport().get_visible_rect().size * 0.5
	var marker := $BallInHandInput/GhostMarker as Node3D
	await _move(centre)
	var spot := marker.position
	_check(spot.distance_to(Vector3(layout.length * 0.5, layout.ball_radius,
			-layout.width * 0.5)) < 0.001, "centre ray lands on the cloth centre")
	await _move(centre + Vector2(120.0, 0.0))
	_check(marker.position.x > spot.x + 0.01, "rightward mouse moves the ghost right")
	await _move(centre + Vector2(0.0, -120.0))
	_check(marker.position.z < spot.z - 0.01, "upward mouse moves the ghost toward the far rail")
	# A horizontal ray never reaches the cloth, so the last valid spot stands.
	var held := marker.position
	camera.rotation = Vector3.ZERO
	await _move(centre)
	_check(marker.position == held, "horizontal ray leaves the ghost where it was")
	print("ball-in-hand pointer: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _move(screen: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	Input.parse_input_event(motion)
	await get_tree().process_frame
	await get_tree().process_frame


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fail(note)


func _fail(note: String) -> void:
	_fails += 1
	printerr("  FAIL: ", note)
