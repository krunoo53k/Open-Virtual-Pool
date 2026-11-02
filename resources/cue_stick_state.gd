class_name CueStickState extends Resource

## The cue's pose, in the form the view draws it.
##
## `pivot` is the centre of the ball the cue is pointed at. `level_aim_deg`
## is the aim in the same intent terms `ShotParams` uses: degrees from the
## table's long axis towards the shooter's left.
##
## `axis_elevation_deg` is NOT how much the player raised the butt. It is the
## tilt of the cue's own axis as read back off the shot - the
## `ShotPreview.elevation_deg` number (§12.3's sign): a raised butt reads
## NEGATIVE here and points the cue down at the ball, so the drawn cue and
## the physics can never disagree about which way the cue lies.
##
## `tip_gap_m` is the distance from the ball's centre to the cue's tip
## along the cue's axis: a draw pull-back is a larger gap, not a new field.

@export var pivot := Vector3.ZERO  # m, Godot's frame: centre of the ball the cue points at.
@export var level_aim_deg := 90.0  # deg: from the table's long axis towards the shooter's left.
@export var axis_elevation_deg := 0.0  # deg: cue axis tilt read off the shot; raised butt negative.
@export var tip_gap_m := 0.032  # m: ball centre to tip along the cue axis.
