class_name TurnStatus
extends VBoxContainer

## Display-only match status: whose turn it is, each player's group tag and
## how many object balls are still on the table. It reads the MatchState it is
## handed and never decides what any of those values should be.

func show_state(state: MatchState) -> void:
	$TurnLabel.text = "player %d to shoot" % state.player
	$Groups/P1Group.text = _tag(state, 1)
	$Groups/P2Group.text = _tag(state, 2)
	$RemainingLabel.text = "remaining: %d" % state.remaining.size()


func turn_text() -> String:
	return $TurnLabel.text


func group_text(player: int) -> String:
	return ($Groups/P1Group as Label).text if player == 1 else ($Groups/P2Group as Label).text


func remaining_text() -> String:
	return $RemainingLabel.text


func _tag(state: MatchState, player: int) -> String:
	if state.solids_player == 0:
		return "open"
	return "solids" if state.solids_player == player else "stripes"
