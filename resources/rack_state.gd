class_name RackState extends Resource

## Every ball the simulation sees, as one hand-off.
##
## Positions and rotations are **flat f64 triples in the core frame**: `x` runs
## along the table, `y` across it and `z` up. There are three consecutive
## numbers per ball. This is the frame the wire uses too (§5 of the online
## plan), so a rack can cross a WebSocket unchanged: no Vector2/Vector3
## packing and no f32 round trip on the way in.
##
## Godot draws with `y` up. `get_position(i)` / `get_rotation(i)` apply the
## one-way display transform `(x, z, -y)`; `set_position(i, v)` /
## `set_rotation(i, v)` apply its inverse `(x, -z, y)`. The transform has no
## translation and must **never** be applied twice: read with the accessors,
## never by indexing `positions` directly when you need a Vector3.
##
## The lists index each other: the ball at index `i` carries the number at
## index `i` and, when `rotations` is not empty, the rotation triple at index
## `i` (axis times radians, §11.2). The cue ball is number zero and sits first.
## `rotations` left empty means every ball starts at identity; a game that
## strikes one shot after another copies the rotations the last shot left
## behind, so spin carries (§11.2's hand-off seen from the input side).
##
## Hotseat still resolves through the old f32 bridge, which wants Godot-frame
## `PackedVector3Array`s; `PoolSimulation` is the only place that converts
## back for that legacy call. The f64 intent entry point replaces it at C1
## stage 2. See docs/online-multiplayer.md for the timeline and the sunset
## date of the hotseat path.

@export var positions: Array[float] = []  # m, flat core-frame triples (x along, y across, z up).
@export var numbers := PackedInt32Array()  # the number every triple carries.
@export var rotations: Array[float] = []  # rad, flat core-frame axis-times-angle triples.


## Ball count is the length of the index-aligned `numbers` list.
func ball_count() -> int:
	return numbers.size()


## The one-way core -> display transform: `(x, y, z)` -> `(x, z, -y)`.
static func display_vector(flat: Array, index: int) -> Vector3:
	var k: int = index * 3
	if k < 0 or k + 2 >= flat.size():
		return Vector3.ZERO
	return Vector3(float(flat[k]), float(flat[k + 2]), -float(flat[k + 1]))


## The inverse display -> core transform: `(x, y, z)` -> `(x, -z, y)`.
static func core_triple(display: Vector3) -> Array[float]:
	return [display.x, -display.z, display.y] as Array[float]


## Godot frame -> flat core frame, for seeded racks and the legacy bridge.
static func flat_from_display(vectors: PackedVector3Array) -> Array[float]:
	var flat: Array[float] = []
	for vector in vectors:
		flat.append_array(core_triple(vector))
	return flat


## Flat core frame -> Godot frame, only for the legacy f32 bridge and views.
static func display_from_flat(flat: Array[float]) -> PackedVector3Array:
	var vectors := PackedVector3Array()
	for i in range(flat.size() / 3):
		vectors.append(display_vector(flat, i))
	return vectors


func get_position(index: int) -> Vector3:
	return display_vector(positions, index)


func get_rotation(index: int) -> Vector3:
	return display_vector(rotations, index)


func set_position(index: int, display: Vector3) -> void:
	var k: int = index * 3
	if k < 0 or k + 2 >= positions.size():
		return
	var triple := core_triple(display)
	positions[k] = triple[0]
	positions[k + 1] = triple[1]
	positions[k + 2] = triple[2]


func set_rotation(index: int, display: Vector3) -> void:
	var k: int = index * 3
	if k < 0 or k + 2 >= rotations.size():
		return
	var triple := core_triple(display)
	rotations[k] = triple[0]
	rotations[k + 1] = triple[1]
	rotations[k + 2] = triple[2]


## Convenience for harnesses that build a rack one ball at a time; keeps the
## three index-aligned lists in step without exposing the frame to callers.
func add_ball(number: int, display_position: Vector3,
		display_rotation := Vector3.ZERO) -> void:
	numbers.append(number)
	positions.append_array(core_triple(display_position))
	rotations.append_array(core_triple(display_rotation))


func duplicate_rack() -> RackState:
	var copy := RackState.new()
	copy.numbers = PackedInt32Array(numbers)
	copy.positions = positions.duplicate()
	copy.rotations = rotations.duplicate()
	return copy


## Plain JSON-ready data for the shot log and protocol fixtures. Triples stay
## triples; only the numbers become core-frame, hence the `frame` marker.
static func to_triples(flat: Array[float]) -> Array:
	var out: Array = []
	for i in range(flat.size() / 3):
		var v := display_vector(flat, i)
		# The wire/log want CORE frame, so undo the display transform here:
		# core (x, y, z) is display (x, z, -y) -> (v.x, -v.z, v.y).
		out.append([v.x, -v.z, v.y])
	return out
