class_name PauseMenu
extends PanelContainer

## Resume / Restart / Back to menu as three plain buttons. The menu only says
## what was pressed; what restarting or leaving means belongs to the composer.

signal resume_requested()
signal restart_requested()
signal menu_requested()

func set_open(open: bool) -> void:
	visible = open


func is_open() -> bool:
	return visible


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()
