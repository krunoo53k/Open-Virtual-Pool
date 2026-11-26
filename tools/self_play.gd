extends Node3D

## Dev-only self-play: one full eight-ball match, both seats driven by the
## same simple potting policy through Match.take_shot (the public entry an AI
## would use). Real physics, rules, rack bookkeeping and phases; only the
## decision-making is scripted. Prints and saves a shot-by-shot transcript.

const MAX_SHOTS := 120

var _lines: Array[String] = []
var _before := PackedInt32Array()
var _ruling: Judgement
var _planned_target := -1
var _planned_pocket := -1
var _over := false
var _winner := 0
var _fails := 0


func _ready() -> void:
	var game: Match = $Match
	$Match/ShotPlayback.time_scale = 1000.0
	game.get_node("MatchFlow").judgement_made.connect(_on_ruling)
	game.match_finished.connect(_on_finished)
	for shot_number in range(1, MAX_SHOTS + 1):
		await _settle(game)
		if _over:
			break
		var params := _plan(game)
		var shooter := game.get_current_player()
		_ruling = null
		_before = PackedInt32Array(game.get_state().remaining)
		game.take_shot(params)
		await _resolve()
		_record(shot_number, shooter, game, params)
	_report()


func _settle(game: Match) -> void:
	for _i in range(600):
		var phase := game.get_phase()
		if phase == "GameOver" or phase == "AwaitingShot":
			return
		if phase == "BallInHand":
			PlacementHelper.place_cue($Match/BallInHandInput,
				game.get_node("Simulation").layout, game.rack)
		await get_tree().process_frame
	_fails += 1
	printerr("self-play stalled in phase ", game.get_phase())


func _resolve() -> void:
	for _i in range(600):
		if _ruling != null:
			return
		await get_tree().process_frame
	_fails += 1
	printerr("self-play: a shot produced no ruling")


func _plan(game: Match) -> ShotParams:
	var rack: RackState = game.rack
	var state: MatchState = game.get_state()
	var sim: PoolSimulation = game.get_node("Simulation")
	var layout: TableLayout = sim.layout
	var cue_index := rack.numbers.find(0)
	var cue_pos := rack.get_position(cue_index)
	var cue_flat := Vector2(cue_pos.x, cue_pos.z)
	var group := 0
	if state.solids_player != 0:
		group = 1 if state.solids_player == state.player else 2
	var targets: Array[int] = []
	if state.break_next:
		targets.append(1)
	else:
		var on_eight := group != 0
		for number in state.remaining:
			if number == 8:
				continue
			if group == 0 or $Match/Rules.group_of(number) == group:
				targets.append(number)
				on_eight = false
		if on_eight:
			targets = [8]
	var best := 1.0e9
	var chosen := ShotParams.new()
	_planned_target = -1
	_planned_pocket = -1
	for target in targets:
		var index := rack.numbers.find(target)
		if index < 0:
			continue
		var ball_pos := rack.get_position(index)
		var ball_flat := Vector2(ball_pos.x, ball_pos.z)
		for pocket in layout.pocket_mouth_centres.size():
			var params := _aim(cue_flat, ball_flat,
				layout.pocket_mouth_centres[pocket], layout.ball_radius)
			var ghost := sim.ghost_of(params, rack)
			if not ghost.has_hit or ghost.hit_ball_number != target:
				continue
			var to_pocket := (layout.pocket_mouth_centres[pocket] - ball_flat).normalized()
			var ghost_flat := Vector2(ghost.ghost_position.x, ghost.ghost_position.z)
			var cut := (ghost_flat - cue_flat).normalized().dot(to_pocket)
			var score := (1.0 - cut) * 6.0 + cue_flat.distance_to(ghost_flat) * 0.4
			if state.break_next:
				score = 0.0
			if score < best:
				best = score
				chosen = params
				_planned_target = target
				_planned_pocket = pocket
				if target == 8:
					params.called_pocket = pocket
	if _planned_target < 0:
		# No clean ghost to any pocket: hit the nearest legal ball and let the
		# rail requirement be satisfied by the roll.
		var nearest := -1
		var near := 1.0e9
		for target in targets:
			var index := rack.numbers.find(target)
			if index < 0:
				continue
			var other := rack.get_position(index)
			var d := cue_flat.distance_to(Vector2(other.x, other.z))
			if d < near:
				near = d
				nearest = target
		if nearest > 0:
			var index := rack.numbers.find(nearest)
			var nearest_pos := rack.get_position(index)
			var ball_flat := Vector2(nearest_pos.x, nearest_pos.z)
			chosen = _aim(cue_flat, ball_flat, cue_flat, layout.ball_radius)
			chosen.called_pocket = -1
			_planned_target = nearest
	return chosen


func _aim(cue_flat: Vector2, ball_flat: Vector2, pocket_flat: Vector2,
		radius: float) -> ShotParams:
	var ghost := ball_flat
	if pocket_flat != cue_flat:
		ghost = ball_flat - (pocket_flat - ball_flat).normalized() * 2.0 * radius
	var leave := ghost - cue_flat
	var params := ShotParams.new()
	var distance := cue_flat.distance_to(ghost) + ball_flat.distance_to(pocket_flat)
	params.speed = clampf(2.6 + distance * 1.1, 3.0, 6.5)
	params.level_aim_deg = rad_to_deg(atan2(-leave.y, leave.x))
	return params


func _record(shot_number: int, shooter: int, game: Match, params: ShotParams) -> void:
	if _ruling == null:
		return
	var after: PackedInt32Array = game.get_state().remaining
	var pots: Array[int] = []
	for number in _before:
		if not after.has(number):
			pots.append(number)
	var line := "shot %02d P%d target=%d pocket=%d aim=%.2f speed=%.2f | foul=%s pots=%s remaining=%d" % [
		shot_number, shooter, _planned_target, _planned_pocket,
		params.level_aim_deg, params.speed, _ruling.foul_reason, str(pots), after.size(),
	]
	_lines.append(line)
	print(line)


func _on_ruling(ruling: Judgement) -> void:
	_ruling = ruling


func _on_finished(winner: int) -> void:
	_over = true
	_winner = winner


func _report() -> void:
	var summary := "self-play: %d shots, winner %d, finished %s" % [
		_lines.size(), _winner, str(_over),
	]
	_lines.append(summary)
	print(summary)
	if _fails > 0:
		printerr("self-play: ", _fails, " harness failures")
	var file := FileAccess.open("user://self_play_transcript.txt", FileAccess.WRITE)
	if file != null:
		for line in _lines:
			file.store_line(line)
		file.close()
	get_tree().quit(1 if _fails > 0 or not _over else 0)
