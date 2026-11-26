class_name MainMenu
extends Control

## Composes the splash, title buttons and options panel, then routes their
## intents. It never builds nodes or decides any rules.

const MATCH_SCENE := "res://scenes/match/match.tscn"
const ONLINE_SCENE := "res://scenes/online/lobby/lobby.tscn"


func _ready() -> void:
	$TitleButtons.play_requested.connect(play)
	$TitleButtons.online_requested.connect(show_lobby)
	$TitleButtons.options_requested.connect(show_options)
	$TitleButtons.quit_requested.connect(quit)
	$OptionsPanel.back_requested.connect(hide_options)


func play() -> void:
	if not ResourceLoader.exists(MATCH_SCENE):
		print("MainMenu: match scene is not available yet (%s); hotseat 2P match not started" % MATCH_SCENE)
		return
	get_tree().change_scene_to_file(MATCH_SCENE)


func show_lobby() -> void:
	if not ResourceLoader.exists(ONLINE_SCENE):
		print("MainMenu: online lobby is not available yet (%s)" % ONLINE_SCENE)
		return
	get_tree().change_scene_to_file(ONLINE_SCENE)


func show_options() -> void:
	$OptionsPanel.show()


func hide_options() -> void:
	$OptionsPanel.hide()


func quit() -> void:
	get_tree().quit(0)
