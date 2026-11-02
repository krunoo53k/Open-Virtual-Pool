class_name ShotOutcome extends Resource

## What a resolved shot ended in, told the way the game reads it.
##
## Every ball is a number, so `pocketed` and `off_table` are number lists.
## `phase` is the core's own word - `settled`, `settling` (still moving when
## the time limit cut the shot), `faulted` (the shot never ran) - and `error`
## carries the fault's detail, empty when there was none. A faulted shot
## still produces an outcome: nothing here crashes on one, and the scenes
## downstream of the adapter decide what a fault means.

@export var elapsed_time := 0.0  # s: the shot's own clock at its end.
@export var phase := ""  # the core's phase word for this shot.
@export var foul := false  # the core already decided; this scene only reports.
@export var miscue := false  # the tip held the cue ball past its limit (§6.3).
@export var pocketed: Array[int] = []  # ball numbers sunk during the shot.
@export var off_table: Array[int] = []  # ball numbers that left the bed.
@export var error := ""  # empty, or the fault the simulation reported.
