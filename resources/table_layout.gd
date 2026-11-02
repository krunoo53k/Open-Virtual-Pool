class_name TableLayout extends Resource

## The table's numbers in Godot's frame, built once from the core's geometry.
##
## This is the only place the core's plane ever crosses into Godot's: the core
## lays the table out right-handed with `x` along the length, `y` across and
## `z` up, and Godot reads the plane as `(x, up, -y)` - so a plane coordinate
## `(x, y)` becomes `(x, -y)` and anything measured towards `+y` - a rail line,
## a facing angle - flips sign. A renderer consumes this; it never parses the
## core's Dictionary again.
##
## Rails and pockets keep their core order, so `rail_lines[i]` belongs to
## `rail_labels[i]`, and the jaws sit two per pocket at `pocket * 2 + jaw`.

## The playfield, metres: length along Godot's `x`, width across Godot's `z`.
@export var length := 2.54
@export var width := 1.267
@export var ball_radius := 0.028575
@export var rail_top_height := 0.0

## The cushion model, angle-free numbers the physics uses (§10.2).
@export var cushion_epsilon := 0.0
@export var cushion_theta := 0.0
@export var cushion_cos_theta := 0.0

## Rails, in core order. Normals and tangents are mirrored into Godot's plane.
@export var rail_labels: Array[String] = []
@export var rail_lines: Array[float] = []  # m, the mirrored signed line coordinate.
@export var rail_normals: Array[Vector2] = []
@export var rail_tangents: Array[Vector2] = []
@export var rail_spans: Array[Vector2] = []  # (lo, hi) along the rail, metres.

## Pockets, in core order. Jaws sit two per pocket: `pocket * 2 + jaw`.
@export var pocket_labels: Array[String] = []
@export var pocket_kinds: Array[String] = []
@export var pocket_mouth_centres: Array[Vector2] = []
@export var pocket_centrelines: Array[Vector2] = []
@export var pocket_widths: Array[float] = []  # m, jaw tip to jaw tip.
@export var pocket_facing_angles: Array[float] = []  # rad, mirrored.
@export var pocket_shelf_depths: Array[float] = []  # m.
@export var pocket_jaw_tips: Array[Vector2] = []
@export var pocket_jaw_ends: Array[Vector2] = []
@export var pocket_jaw_normals: Array[Vector2] = []

## Mirror one plane coordinate the core gives into Godot's plane.
static func mirrored(point: Array) -> Vector2:
	return Vector2(float(point[0]), -float(point[1]))

## Build the layout from the Dictionary `PoolCore.get_table_geometry` returns,
## converting every plane number exactly once.
static func build(geometry: Dictionary) -> TableLayout:
	var layout := TableLayout.new()
	(layout).length = float(geometry["length"])
	(layout).width = float(geometry["width"])
	(layout).ball_radius = float(geometry["ball_radius"])
	(layout).rail_top_height = float(geometry["cushion"]["rail_top_height"])
	(layout).cushion_epsilon = float(geometry["cushion"]["epsilon"])
	(layout).cushion_theta = float(geometry["cushion"]["theta"])
	(layout).cushion_cos_theta = float(geometry["cushion"]["cos_theta"])
	(layout).append_rails(geometry["rails"])
	(layout).append_pockets(geometry["pockets"])
	return layout


## Copy the rails, mirroring each plane vector once.
func append_rails(rails: Array) -> void:
	for rail in rails:
		(rail_labels).append(String(rail["label"]))
		(rail_lines).append(-float(rail["line"]))
		(rail_normals).append(mirrored(rail["normal"]))
		(rail_tangents).append(mirrored(rail["tangent"]))
		for span in rail["spans"]:
			(rail_spans).append(Vector2(float(span[0]), float(span[1])))


## Copy the pockets and their two jaws each, mirroring every plane vector.
func append_pockets(pockets: Array) -> void:
	for pocket in pockets:
		(pocket_labels).append(String(pocket["label"]))
		(pocket_kinds).append(String(pocket["kind"]))
		(pocket_mouth_centres).append(mirrored(pocket["mouth_centre"]))
		(pocket_centrelines).append(mirrored(pocket["centreline"]))
		(pocket_widths).append(float(pocket["width"]))
		(pocket_facing_angles).append(-float(pocket["facing_angle"]))
		(pocket_shelf_depths).append(float(pocket["shelf_depth"]))
		for jaw in pocket["jaws"]:
			(pocket_jaw_tips).append(mirrored(jaw["tip"]))
			(pocket_jaw_ends).append(mirrored(jaw["end"]))
			(pocket_jaw_normals).append(mirrored(jaw["normal"]))
