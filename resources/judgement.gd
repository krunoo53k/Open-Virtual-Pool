class_name Judgement extends Resource

## What the rules decided about one shot - pure data, no methods.
##
## The ruling never stores itself anywhere: the composer applies it to its
## own `MatchState` copy and hands it to the HUD. The reason strings are
## the fixture contract (stable words): `scratch`, `ball_off_table`,
## `wrong_group_first_contact`, `no_contact`, `no_rail_after_contact`,
## `illegal_break`, `miscue`, `incomplete_shot`.

@export var foul_reason := ""  # "" means a clean shot; otherwise one stable reason word.
@export var next_player := 0  # who shoots next (0 only when game_over).
@export var ball_in_hand := false  # the next shooter places the cue anywhere (BCA).
@export var re_rack := false  # the rack is rebuilt: 8 on the break, or a foul break.
@export var solids_player := 0  # player newly assigned solids; 0 means "no change this shot".
@export var game_over := false
@export var winner := 0  # 1 or 2 when game_over, 0 otherwise.
