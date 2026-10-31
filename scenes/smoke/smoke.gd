extends Node3D

## Smoke of the GDExtension bridge: does the data survive the trip from Godot
## to the core and back?
##
## The shot is the one pinned in the engine repo's `pool-godot/tests/headless.rs`,
## and both sides pin the same hash: if the extension moves a number on the
## way in or out, the two sides stop agreeing and this check fails.
##
## Run it headless with:
##
##     godot --headless --path . res://scenes/smoke.tscn
##
## The exit code is 0 when the hash matches, 1 when it does not.

## The hash of the shot, pinned. The same value is in the engine repo.
const HASH := "c399229b25faae5a"

## The radius of the ball, which is where the balls sit above the bed.
const RADIUS := 0.028575

## The table runs along `x`, `y` is up and `z` is across the table, so the
## core's `+y` is Godot's `-z`.
func _ready() -> void:
	var core := PoolCore.new()
	print("model version: ", core.get_model_version())
	print("miscue limit: ", core.get_miscue_limit(), " m")

	var positions := PackedVector3Array()
	var numbers := PackedInt32Array()
	# The cue ball, a quarter of a metre to the side of the rack.
	positions.append(Vector3(0.25, RADIUS, -0.5625))
	numbers.append(0)
	# The rack: four by four, with one ball missing.
	for row in 4:
		for column in 4:
			if row == 0 and column == 0:
				continue
			positions.append(Vector3(0.5 + 0.0625 * column, RADIUS, -(0.5 + 0.0625 * row)))
			numbers.append(positions.size() - 1)

	# The cue travels along the core's `+y`, which is Godot's `-z`.
	var shot := core.simulate(8.0, Vector3(0.0, 0.0, -1.0), Vector2.ZERO, positions, numbers)

	print("duration: ", shot.get_duration(), " s")
	print("events: ", shot.get_events().size())
	var error := shot.get_error()
	if error != "":
		printerr("the shot faulted: ", error)

	var shot_hash := shot.get_hash()
	print("hash: ", shot_hash)

	# The path, read back the way a renderer reads it.
	var duration := shot.get_duration()
	var t := 0.0
	while t < duration:
		if t == 0.0 or is_equal_approx(t, duration * 0.5):
			print("at ", t, " s the cue ball is at ", shot.sample(t)[0])
		t += duration / 10.0

	var ok := shot_hash == HASH and error == ""
	if ok:
		print("the hash matches the pinned value and the shot did not fault")
	else:
		printerr("the check failed: got ", shot_hash, ", expected ", HASH)

	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if ok else 1)
