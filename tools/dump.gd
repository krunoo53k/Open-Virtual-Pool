extends Node3D

func _ready() -> void:
	var core := PoolCore.new()
	var positions := PackedVector3Array()
	var numbers := PackedInt32Array()
	positions.append(Vector3(0.25, 0.028575, -0.5625))
	numbers.append(0)
	for row in 4:
		for column in 4:
			if row == 0 and column == 0:
				continue
			positions.append(Vector3(0.5 + 0.0625 * column, 0.028575, -(0.5 + 0.0625 * row)))
			numbers.append(positions.size() - 1)
	var shot: PoolShot = core.simulate(8.0, Vector3(0.0, 0.0, -1.0), Vector2.ZERO, positions, numbers)
	var fs: Dictionary = shot.get_final_state()
	print("FINAL KEYS: ", fs.keys())
	for k in fs:
		var v = fs[k]
		if v is Array:
			print(k, " count=", v.size(), " first=", v[0])
		else:
			print(k, " -> ", v)
	print("BALL STATE 0: ", shot.get_ball_state(0))
	print("EVENTS[0..2]: ", shot.get_events().slice(0, 3))
	var rot := shot.sample_rotation(shot.get_duration())
	print("ROTATIONS size=", rot.size(), " first=", rot[0], " second=", rot[1])
	get_tree().quit(0)
