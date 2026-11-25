class_name ResultBanner
extends PanelContainer

## Win/loss banner. A winner of 0 means no game was decided, so the banner is
## hidden; otherwise it names the winner the Judgement reported and offers a
## way back to the main menu. It only announces the intent.

signal menu_requested()

func show_result(winner: int) -> void:
	$Margin/VBox/WinnerLabel.text = "player %d wins!" % winner if winner != 0 else ""
	visible = winner != 0


func result_text() -> String:
	return $Margin/VBox/WinnerLabel.text if visible else ""


func _on_back_to_menu_pressed() -> void:
	menu_requested.emit()
