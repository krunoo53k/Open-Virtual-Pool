class_name DisplayRay extends RefCounted

## The one place the aim-display ray test sits, behind the adapter's typed
## door. Views display its answer and never derive it; the acceptance test
## pins it against the path the core samples at the same strike (§11.4).

static func stretch_of(rack: RackState, preview: ShotPreview, layout: TableLayout) -> ShotGhost:
	var cue_index := 0
	for i in rack.numbers.size():
		if rack.numbers[i] == 0:
			cue_index = i
			break
	var cue := rack.positions[cue_index]
	var leave := Vector3(preview.velocity.x, 0.0, preview.velocity.z)
	if leave.length() < 1.0e-6:
		var dead := ShotGhost.new()
		dead.ghost_position = cue
		dead.line_end = cue
		dead.hit_position = cue
		return dead
	leave = leave.normalized()
	var contact := 2.0 * layout.ball_radius
	var best := INF
	var hit := -1
	for i in rack.numbers.size():
		if i == cue_index:
			continue
		var ox := rack.positions[i].x - cue.x
		var oz := rack.positions[i].z - cue.z
		var along := ox * leave.x + oz * leave.z
		if along <= 0.0:
			continue
		var across_sq := ox * ox + oz * oz - along * along
		if across_sq > contact * contact:
			continue
		var back := sqrt(maxf(0.0, contact * contact - across_sq))
		var candidate := maxf(0.0, along - back)
		if candidate < best:
			best = candidate
			hit = i
	var ghost := ShotGhost.new()
	ghost.line_end = cue + leave * _rail_along(cue, leave, layout)
	if hit >= 0:
		ghost.has_hit = true
		ghost.hit_ball_number = rack.numbers[hit]
		ghost.hit_position = rack.positions[hit]
		ghost.ghost_position = cue + leave * best
		ghost.line_end = ghost.ghost_position
	return ghost


static func _rail_along(cue: Vector3, leave: Vector3, layout: TableLayout) -> float:
	# cloth bounds in Godot's plane: x 0..length, z +/- width/2
	var best := INF
	if leave.x > 0.0:
		best = minf(best, (layout.length - cue.x) / leave.x)
	elif leave.x < 0.0:
		best = minf(best, -cue.x / leave.x)
	if leave.z > 0.0:
		best = minf(best, (layout.width * 0.5 - cue.z) / leave.z)
	elif leave.z < 0.0:
		best = minf(best, (-layout.width * 0.5 - cue.z) / leave.z)
	if best == INF:
		return 0.0
	return maxf(best, 0.0)
