class_name TitleButtons
extends Control

## The title screen's buttons. It emits what the player asked for without
## knowing which scene will answer it.

signal play_requested
signal online_requested
signal options_requested
signal quit_requested


func _ready() -> void:
	$Menu/PlayButton.pressed.connect(_on_play_pressed)
	$Menu/OnlineButton.pressed.connect(_on_online_pressed)
	$Menu/OptionsButton.pressed.connect(_on_options_pressed)
	$Menu/QuitButton.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	play_requested.emit()


func _on_online_pressed() -> void:
	online_requested.emit()


func _on_options_pressed() -> void:
	options_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
