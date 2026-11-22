class_name MainMenu
extends Control

## Composes the splash, title buttons and options panel, then routes their
## intents. It never builds nodes or decides any rules.

const MATCH_SCENE := "res://scenes/match/match.tscn"


func _ready() -> void:
	$TitleButtons.play_requested.connect(play)
	$TitleButtons.options_requested.connect(show_options)
	$TitleButtons.quit_requested.connect(quit)
	$OptionsPanel.back_requested.connect(hide_options)


func play() -> void:
	if not ResourceLoader.exists(MATCH_SCENE):
		print("MainMenu: match scene is not available yet (%s); hotseat 2P match not started" % MATCH_SCENE)
		return
	get_tree().change_scene_to_file(MATCH_SCENE)


func show_options() -> void:
	$OptionsPanel.show()


func hide_options() -> void:
	$OptionsPanel.hide()


func quit() -> void:
	get_tree().quit(0)
