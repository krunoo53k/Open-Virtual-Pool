class_name MatchState extends Resource

## Everything true about the match between shots - passed in and returned,
## never stored in a global. The rules read it; the composer owns it.
##
## Players are numbered 1 and 2. `solids_player` is 0 while the table is
## open (BCA: the break never assigns groups). `remaining` carries the
## object-ball numbers still on the table, cue excluded, the 8 among them
## until it is potted: the rules decide "on the 8" from this list as it was
## BEFORE the shot, exactly as BCA rules it.

@export var player := 1  # whose turn it is.
@export var solids_player := 0  # 0 while open; otherwise the player holding 1-7.
@export var remaining := PackedInt32Array()  # object numbers still on the table (cue excluded).
@export var ball_in_hand := false  # the next stroke places the cue anywhere (set by a foul's ruling).
@export var break_next := true  # the next stroke is a break stroke.
