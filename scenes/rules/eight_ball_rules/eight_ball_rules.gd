extends Node
class_name EightBallRules

## BCA eight-ball ruling: `ShotOutcome`, `ShotEvent` array, `ShotParams`
## and the `MatchState` as it was BEFORE the shot in, one `Judgement` out.
## Events are ground truth: the core's `outcome.foul` stays advisory and
## only `outcome.miscue` is read (the rules never ask physics anything).
## The Rust port (card #11) reimplements this table over the same event
## words. The ruling never mutates anything: whoever owns the `MatchState`
## - the fixture runner today, `game.tscn` in card #8 - applies it along
## with its own remaining-ball bookkeeping. `judge_and_announce` fires the
## five announcement signals in the order fixtures assert them: foul,
## group assignment, ball-in-hand grant, turn or game over.

signal foul_committed(reason: String)
signal groups_assigned(solids_player: int)
signal ball_in_hand_granted(player: int)
signal turn_changed(player: int)
signal game_over(winner: int)


func group_of(n: int) -> int:
	if n == 8:
		return 0
	return 1 if n >= 1 and n <= 7 else 2


func judge(outcome: ShotOutcome, params: ShotParams, events: Array[ShotEvent], state: MatchState) -> Judgement:
	return _rule(outcome, params, events, state)


func judge_and_announce(outcome: ShotOutcome, params: ShotParams, events: Array[ShotEvent], state: MatchState) -> Judgement:
	var ruling := _rule(outcome, params, events, state)
	_announce(ruling)
	return ruling


func _announce(ruling: Judgement) -> void:
	if ruling.foul_reason != "":
		foul_committed.emit(ruling.foul_reason)
	if ruling.solids_player != 0:
		# A ruling announces only when it assigns; a "no change" ruling is silent.
		# A ruling announces only when it assigns; a "no change" ruling is silent.
	if ruling.game_over:
		# §7.7 and §7.9 announce the result and never the turn as well.
	if ruling.game_over:
		# §7.7 and §7.9 announce the result and never the turn as well.
	...