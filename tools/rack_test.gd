extends Node3D

## Headless acceptance check for issue #2's rack: spots must be seeded from the
## core's own table geometry, the BCA constraints must hold, spacing must be
## legal, and a twin rack with the same seed must reproduce the shuffle.
## Exit code 0 = pass. Run: godot --headless --path . res://tools/rack_test.tscn

const RACK_SCENE := preload("res://scenes/rack/ball_rack/ball_rack.tscn")
const EPS := 0.000001

var _fails: Array[String] = []

func _ready() -> void:
	var geometry: Dictionary = PoolCore.new().get_table_geometry()
	var rack := RACK_SCENE.instantiate()
	rack.set_geometry(geometry)
	add_child(rack)
	var twin := RACK_SCENE.instantiate()
	twin.set_geometry(geometry)
	add_child(twin)
	_check_rack(geometry, rack)
	_check_twin(rack, twin)
	if _fails.is_empty():
		print("RACK OK: core geometry spots, BCA constraints, seeded rerack")
	else:
		for f in _fails:
			printerr("rack fail: ", f)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fails.is_empty() else 1)

func _fail(note: String) -> void:
	_fails.append(note)

func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < EPS

func _check_rack(geometry: Dictionary, rack: BallRack) -> void:
	var l := float(geometry["length"])
	var w := float(geometry["width"])
	var r := float(geometry["ball_radius"])
	var numbers: PackedInt32Array = rack.get_numbers()
	var spots: PackedVector3Array = rack.get_positions()
	if numbers.size() != 16 or spots.size() != 16:
		_fail("sixteen expected, got " + str(numbers.size()) + "/" + str(spots.size()))
		return
	var sorted := Array(numbers)
	sorted.sort()
	for i in 16:
		if int(sorted[i]) != i:
			_fail("numbers are not a permutation of 0..15")
			break
	var head := Vector3(l * 0.25, r, -w * 0.5)
	var foot := Vector3(l * 0.75, r, -w * 0.5)
	if not _near(spots[0], head):
		_fail("cue not on the head spot")
	if numbers[1] != 1 or not _near(spots[1], foot):
		_fail("apex is not the 1 on the foot spot")
	if numbers[5] != 8:
		_fail("eight not in the third-row centre")
	var a := numbers[11]
	var b := numbers[15]
	if not ((a > 0 and a < 8 and b > 8) or (b > 0 and b < 8 and a > 8)):
		_fail("back corners are not one solid and one stripe")
	for i in range(1, 16):
		var p: Vector3 = spots[i]
		if p.x < r - EPS or p.x > l - r + EPS or p.z < -w + r - EPS or p.z > -r + EPS:
			_fail("ball " + str(i) + " sits outside the body")
	for i in range(16):
		for j in range(i + 1, 16):
			if spots[i].distance_to(spots[j]) < 2.0 * r - 10.0 * EPS:
				_fail("balls " + str(i) + " and " + str(j) + " overlap")

func _check_twin(rack: BallRack, twin: BallRack) -> void:
	var na: PackedInt32Array = rack.get_numbers()
	var nb: PackedInt32Array = twin.get_numbers()
	if na != nb:
		_fail("seeded rerack differs")
		return
	var pa: PackedVector3Array = rack.get_positions()
	var pb: PackedVector3Array = twin.get_positions()
	for i in pa.size():
		if not _near(pa[i], pb[i]):
			_fail("rerack spots differ at ball " + str(i))
