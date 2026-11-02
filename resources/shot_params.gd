class_name ShotParams extends Resource

## One stroke, described the way a player means it, before any frame exists.
##
## Every angle is degrees and every offset metres, all in player-intent terms:
## `contact_x` is the distance to the shooter's right, `contact_y` the distance
## above the ball's centre. A positive `elevation_deg` raises the cue at the
## butt (§12.3), which points the cue DOWN at the ball. Nothing negates
## anything on the way out: `PoolSimulation` and `pool-godot/src/frame.rs`
## own every sign and frame conversion, so this stays the same for a human,
## an AI, or a network player.

@export var speed := 8.0  # m/s: how hard the cue ball is struck.
@export var level_aim_deg := 90.0  # deg: aim from the table's long axis towards the shooter's left.
@export var elevation_deg := 0.0  # deg: how much the cue is raised at the butt.
@export var contact_x := 0.0  # m: where the tip meets the cue ball, to the shooter's right.
@export var contact_y := 0.0  # m: where the tip meets the cue ball, above the centre.
