extends Node3D

## Headless acceptance for the shot-log bind: one real shot through Match,
## the L bind, and a JSON dump that carries the same params, rack and hash.

var _fails := 0


func _ready() -> void:
	var game: Match = $Match
	for _i in range(3):
		await get_tree().process_frame
	var logger: ShotDebugLog = game.get_node("ShotDebugLog")
	_check(InputMap.has_action("dump_shot_log"), "the log bind is registered")
	_check(not logger.has_shot(), "nothing is logged before the first stroke")
	# A stale file from an earlier run would make the write assertion vacuous.
	if FileAccess.file_exists(logger.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(logger.path))
	var params := ShotParams.new()
	params.speed = 7.5
	# A double that Godot's default float formatting shortens: the log must not.
	params.level_aim_deg = 0.1801463961601262
	game.take_shot(params)
	for _i in range(10):
		await get_tree().process_frame
		if logger.has_shot():
			break
	_check(logger.has_shot(), "the resolved shot was captured")
	_press_bind()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(FileAccess.file_exists(logger.path), "the bind wrote the log file")
	if FileAccess.file_exists(logger.path):
		_check_full_precision(logger.path)
		_check_json(logger.path, params)
	print("shot log: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _press_bind() -> void:
	var event := InputEventAction.new()
	event.action = "dump_shot_log"
	event.pressed = true
	Input.parse_input_event(event)


func _check_full_precision(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	_check(text.contains("0.1801463961601262"), "floats keep full precision")


func _check_json(file_path: String, params: ShotParams) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Dictionary, "the log is a JSON object")
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	var shot: Dictionary = data.get("shot", {})
	var sent: Dictionary = data.get("params", {})
	var rack: Dictionary = data.get("rack_before", {})
	var result: Dictionary = data.get("outcome", {})
	_check(str(shot.get("hash", "")) != "", "the core hash is recorded")
	_check(float(sent.get("speed", 0.0)) == params.speed, "the stroke speed round-trips")
	_check(float(sent.get("level_aim_deg", 0.0)) == params.level_aim_deg, "the aim round-trips")
	_check(Array(rack.get("numbers", [])).size() == 16, "the pre-shot rack is complete")
	_check(Array(rack.get("positions", [])).size() == 16, "the pre-shot positions are complete")
	_check(str(result.get("phase", "")) != "", "the outcome is recorded")
	_check(float(data.get("model_version", 0.0)) > 0.0, "the model version is recorded")


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fails += 1
		printerr("  FAIL: ", note)
