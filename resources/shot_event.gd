class_name ShotEvent extends Resource

## One core event, already in ball-number terms.
##
## The core's `get_events()` gives Dictionaries with `time`, `kind`, `a`,
## `b`, `detail` - where `a`/`b` are ball INDICES for `ball-ball`, an index +
## rail for `cushion`, an index + pocket for the pocket kinds. This record
## carries the same fields but with `ball` and `other` as BALL NUMBERS: the
## composer that converts the raw Dictionaries maps indices through the
## `RackState.numbers` it passed in, so nothing downstream ever sees indices.
##
## `kind` carries the core's own word (`ball-ball`, `cushion`, `jaw`, `slate`,
## `state`, `pocket-enter`, `pocket-drop`, `pocket-exit`, `off-table`): the
## ruling reads events as ground truth, and the Rust port reuses these words
## unchanged. `pocket-drop` is the only pot; a `pocket-enter` followed by a
## `pocket-exit` (a rattle out) never counts as one.

@export var kind := ""  # the core's own kind word, unchanged.
@export var ball := -1  # m-free: the event's ball number (cue is 0).
@export var other := -1  # by kind: other ball number, rail index, or pocket index (core order 0-5: corners first, then sides).
@export var detail := 0  # the core's detail word (rail regime for cushions, jaw index for jaws).
@export var time := 0.0  # s: the shot clock when the event happened; the array is in shot order.
