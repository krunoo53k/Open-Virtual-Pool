extends Node3D

## Headless check of BallInHandInput's pointer-to-cloth ray. The legality
## harness drives place_at directly; this one holds M and injects real
## mouse-motion events, then checks that the ghost follows the ray onto the
## cloth only while the hold is down. Exit code is the number of failed
## assertions.

var _fails := 0


func _ready() -> void:
	var layout := TableLayout.new()
	var camera := $Camera as Camera3D
	camera.position = Vector3(layout.length * 0.5, 2.0, -layout.width * 0.5)
	camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)  # straight down, screen right is +x
	await get_tree().process_frame
	var input := $BallInHandInput as BallInHandInput
	input.layout = layout
	input.camera = camera
	input.activate()
	var centre := get_viewport().get_visible_rect().size * 0.5
	var marker := $BallInHandInput/GhostMarker as Node3D
	# A drag without the hold is just an aim turn, not a cue placement.
	await _move(centre)
	var head := RackModel.head_spot(layout)
	_check(marker.position.distance_to(head) < 0.0001, "pointer motion without M leaves the ghost on the head spot")

	Input.action_press("ball_in_hand")
	await _move(centre)
	var spot := marker.position
	_check(spot.distance_to(head) > 0.01, "holding M puts the ghost under the pointer")
	await _move(centre + Vector2(120.0, 0.0))
	_check(marker.position.x > spot.x + 0.01, "rightward mouse moves the ghost right")
	await _move(centre + Vector2(0.0, -120.0))
	_check(marker.position.z < spot.z - 0.01, "upward mouse moves the ghost toward the far rail")
	Input.action_release("ball_in_hand")

	var held := marker.position
	await _move(centre)
	_check(marker.position == held, "releasing M leaves the ghost where it was")
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
