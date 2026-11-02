class_name ShotPreview extends Resource

## What the same strike would do, short of running it.
##
## The adapter fills this from the core's own preview call, so the promise
## cannot drift: the leave direction comes from the same strike the shot
## would use, squirt included. Views display these numbers; they never
## re-derive them.
##
## `elevation_deg` is read back off the cue axis - a cue raised at the butt
## points down at the ball and reads NEGATIVE here, the opposite sign to the
## raise a `ShotParams` carries.

@export var velocity := Vector3.ZERO  # m/s: the cue ball's real leave direction, squirt baked in.
@export var squirt_deg := 0.0  # deg: sideways throw of the leave against the aim.
@export var squirt_sign := 0.0  # +1 or -1: which side of the aim the leave takes.
@export var miscue := false  # the tip would hold the cue ball past its limit (§6.3).
@export var impact_parameter := 0.0  # -1..1: where the tip meets, limit-normalised.
@export var elevation_deg := 0.0  # deg: the cue axis' height, raised butt negative.
