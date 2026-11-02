class_name ShotGhost extends Resource

## What a previewed stretch shows on the cloth: a cue ball's ghost point and
## the ball it first touched. The adapter's one ray test fills this in from
## the core's own leave direction, so what the view draws and the path the
## core samples cannot diverge for the same strike (§11.4). All positions
## are Godot-frame metres.

@export var ghost_position := Vector3.ZERO  # m: cue-ball centre at first touch, along the leave direction
@export var has_hit := false  # the stretch touched a ball before the rails
@export var hit_ball_number := -1  # which ball that was (-1 when nothing was touched)
@export var hit_position := Vector3.ZERO  # m: that ball's centre, for the marker
@export var line_end := Vector3.ZERO  # m: where the aim line stops (the ghost, or the near rail)
