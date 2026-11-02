class_name CueTuning extends Resource

## One stroke's tuning: every gesture's scale, at the same numbers the
## playground ran with (§6.2's stroke speed and §12.3's elevation). A
## Resource, not a wall of consts, so the game can be retuned from the
## inspector without touching a scene.

@export var max_pull_m := 0.30  # m: how far back the cue may go.
@export var draw_speed_m_per_px := 0.002  # m per px of draw drag.
@export var min_cue_speed_m_s := 0.15  # m/s: the softest stroke the game takes.
@export var max_cue_speed_m_s := 9.0  # m/s: the hardest stroke the game takes.
@export var stroke_at_impact := 2.0  # x: the cue meets the ball at twice the tempo it ran over (§6.2).
@export var angle_per_pixel_deg := 0.1  # deg per px of raise drag.
@export var max_cue_angle_deg := 60.0  # deg: a bridge cannot follow a shaft steeper (§12.3).
@export var look_speed_rad_per_px := 0.0035  # rad per px of aim turn.
@export var spin_scale_m_per_px := 0.00028  # m per px of tip move.
@export var fine_scale := 0.25  # x: fine trim holds the same drag back.
