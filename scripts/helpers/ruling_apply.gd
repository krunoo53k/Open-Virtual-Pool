class_name RulingApply
extends RefCounted

## Fold one Judgement into the composer's MatchState. The rules decide; this
## only records the decision and keeps the remaining-ball list honest (§7.4).
## The fixture runner folds the same fields by hand; production has one home.

static func apply(state: MatchState, ruling: Judgement, removed: Array[int]) -> void:
	state.player = ruling.next_player
	if ruling.solids_player != 0:
		state.solids_player = ruling.solids_player
	state.ball_in_hand = ruling.ball_in_hand
	state.break_next = ruling.re_rack
	if ruling.re_rack:
		state.remaining = full_rack()
		return
	var kept := PackedInt32Array()
	for n in state.remaining:
		if not removed.has(int(n)):
			kept.append(n)
	state.remaining = kept


static func full_rack() -> PackedInt32Array:
	var rack := PackedInt32Array()
	for number in range(1, 16):
		rack.append(number)
	return rack
