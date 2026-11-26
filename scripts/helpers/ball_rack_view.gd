class_name BallRackView
extends RefCounted

## Keeps the rack's visible Ball nodes in step with a RackState hand-off. The
## rack owns the numbers and the instances; this only places or hides them.
## Balls the model no longer carries are hidden, not freed, so a rerack can
## bring them back without rebuilding the scene.

static func apply_state(view: BallRack, rack: RackState) -> void:
	var spots := {}
	for i in rack.numbers.size():
		var orientation := Vector3.ZERO
		if i * 3 + 2 < rack.rotations.size():
			orientation = rack.get_rotation(i)
		# The accessors apply the one-way core -> display transform; the view
		# never reads the flat core-frame triples directly.
		spots[int(rack.numbers[i])] = {"position": rack.get_position(i),
			"rotation": orientation}
	var numbers := view.get_numbers()
	for i in numbers.size():
		var ball := view.get_child(i) as Ball
		if ball == null:
			continue
		if spots.has(int(numbers[i])):
			var pose: Dictionary = spots[int(numbers[i])]
			ball.visible = true
			ball.place(pose["position"], pose["rotation"])
		else:
			ball.visible = false


static func place_cue(view: BallRack, spot: Vector3) -> void:
	var numbers := view.get_numbers()
	var index := numbers.find(0)
	if index < 0:
		return
	var ball := view.get_child(index) as Ball
	if ball != null:
		ball.visible = true
		ball.place(spot, Vector3.ZERO)
