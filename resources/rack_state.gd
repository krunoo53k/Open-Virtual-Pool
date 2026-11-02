class_name RackState extends Resource

## Every ball the simulation sees, in Godot's frame, as one hand-off.
##
## The lists index each other: the ball at index `i` carries the number at
## index `i` and, when `rotations` is not empty, the rotation vector at
## index `i` (axis times radians, §11.2). The cue ball is the number zero and
## sits first. Positions are already in Godot's frame (`x` along the table's
## length, `y` up, `z` across); the adapter converts the whole list, so no
## producer ever thinks in the core's frame.
##
## `rotations` left empty means every ball starts at identity; a game that
## strikes one shot after another copies the rotations the last shot left
## behind, so spin carries (§11.2's hand-off seen from the input side).

@export var positions := PackedVector3Array()  # m, Godot's frame.
@export var numbers := PackedInt32Array()  # the number every position carries.
@export var rotations := PackedVector3Array()  # rad, axis times angle; empty means identity.
