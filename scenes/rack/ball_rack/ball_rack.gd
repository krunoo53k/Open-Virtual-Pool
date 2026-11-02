extends Node3D
class_name BallRack

## BCA triangle rack for one game: fifteen object balls plus the cue, sixteen
## instances of one Ball scene. Table geometry enters via set_geometry() from a
## consumer, so the rack never reaches into the physics core; the number layout
## follows the BCA constraints and a seeded shuffle, so a rerack replays exactly.
## Spots use the core frame mapped into Godot: x right, y up, core y negated.

@export var rack_seed: int = 20261031
@export var table_length: float = 2.54
@export var table_width: float = 1.27
@export var ball_radius: float = 0.028575

const BALL_SCENE := preload("res://scenes/rack/ball/ball.tscn")
const FOOT_RATIO := 0.75
const HEAD_RATIO := 0.25

var _numbers: Array[int] = []
var _positions: Array[Vector3] = []
var _orientations: Array[Vector3] = []
var _geometry: Dictionary = {}

func _ready() -> void:
	if _geometry.is_empty():
		_geometry = {"length": table_length, "width": table_width,
					 "ball_radius": ball_radius}
	_build()

func set_geometry(geometry: Dictionary) -> void:
	_geometry = geometry

func _build() -> void:
	var l := float(_geometry["length"])
	var w := float(_geometry["width"])
	var r := float(_geometry["ball_radius"])
	_numbers = _draw_numbers()
	_positions = _rack_positions(l, w, r)
	_orientations.resize(_numbers.size())
	for i in _numbers.size():
		var ball := BALL_SCENE.instantiate()
		ball.number = _numbers[i]
		ball.radius_m = r
		add_child(ball)
		ball.place(_positions[i], _orientations[i])

func carry_rotations(shot: PoolShot) -> void:
	# the core hands back final orientations as axis-times-angle; gdscript copies
	# them verbatim and never accumulates a rotation of its own
	var final := shot.sample_rotation(shot.get_duration())
	_orientations.clear()
	for v in final:
		_orientations.append(v)

func get_numbers() -> PackedInt32Array:
	return PackedInt32Array(_numbers)

func get_positions() -> PackedVector3Array:
	return PackedVector3Array(_positions)

func get_orientations() -> PackedVector3Array:
	return PackedVector3Array(_orientations)

func _draw_numbers() -> Array[int]:
	# BCA legal rack: the 1 apex on the foot spot, the 8 in the third-row
	# centre, one solid and one stripe in the back corners, the rest seeded
	var rng := RandomNumberGenerator.new()
	rng.seed = rack_seed
	var out: Array[int] = []
	out.resize(16)
	var solids: Array[int] = [2, 3, 4, 5, 6, 7]
	var stripes: Array[int] = [9, 10, 11, 12, 13, 14, 15]
	_shuffle(solids, rng)
	_shuffle(stripes, rng)
	out[0] = 0
	out[1] = 1
	out[5] = 8
	if rng.randf() < 0.5:
		out[11] = solids.pop_front()
		out[15] = stripes.pop_front()
	else:
		out[11] = stripes.pop_front()
		out[15] = solids.pop_front()
	var pool: Array[int] = solids + stripes
	_shuffle(pool, rng)
	for slot in [2, 3, 4, 6, 7, 8, 9, 10, 12, 13, 14]:
		out[slot] = pool.pop_front()
	return out

func _rack_positions(l: float, w: float, r: float) -> Array[Vector3]:
	# cue on the head spot, apex on the foot spot, rows packed footward
	var out: Array[Vector3] = []
	out.append(_seat(l * HEAD_RATIO, w * 0.5, r))
	var gap := r * sqrt(3.0)
	for row in range(1, 6):
		for j in range(row):
			var x := l * FOOT_RATIO + (row - 1) * gap
			var y := w * 0.5 - (row - 1) * r + j * 2.0 * r
			out.append(_seat(x, y, r))
	return out

func _seat(x: float, y: float, r: float) -> Vector3:
	# core frame: origin at the near head-rail corner, x along the length;
	# Godot keeps x and negates y, and the cloth sits at 0 so the centre is a
	# radius above it
	return Vector3(x, r, -y)

func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	# Fisher-Yates on the caller's array, driven by the seeded generator
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
