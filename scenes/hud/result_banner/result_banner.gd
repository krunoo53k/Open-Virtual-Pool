class_name ResultBanner
extends PanelContainer

## Win/loss banner. A winner of 0 means no game was decided, so the banner is
## hidden; otherwise it names the winner the Judgement reported.

func show_result(winner: int) -> void:
	$WinnerLabel.text = "player %d wins!" % winner if winner != 0 else ""
	visible = winner != 0


func result_text() -> String:
	return $WinnerLabel.text if visible else ""
