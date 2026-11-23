extends Node
class_name MainMenuTest

## Headless acceptance for the menu tree and the persisted options file.

const MENU_SCENE := preload("res://scenes/main_menu/main_menu.tscn")
const CONFIG_PATH := "user://open_virtual_pool.cfg"
const MATCH_PATH := "res://scenes/match/match.tscn"

var _fails: Array[String] = []
var _panel: OptionsPanel
var _seen_fullscreen := false
var _seen_action := ""
var _seen_key := ""


func _ready() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG_PATH))
	var menu := MENU_SCENE.instantiate() as MainMenu
	add_child(menu)
	_panel = menu.get_node("OptionsPanel") as OptionsPanel
	_check(menu.get_node_or_null("BootSplash") is BootSplash, "boot splash is missing")
	var buttons := menu.get_node_or_null("TitleButtons")
	_check(buttons is TitleButtons, "title buttons are missing")
	if buttons != null:
		for button_name in ["PlayButton", "OptionsButton", "QuitButton"]:
			_check(buttons.get_node_or_null("Menu/" + button_name) is Button, "button missing: " + button_name)
	_check(MainMenu.MATCH_SCENE == MATCH_PATH, "Play does not target the match scene")
	_panel.display_mode_changed.connect(_on_display_mode_changed)
	_panel.input_remapped.connect(_on_input_remapped)
	_round_trip()
	_panel.get_node("Panel/Margin/VBox/ResetKeys").pressed.emit()
	_check(InputRemap.label_for_action("cue_draw") == "S",
		"reset restores the shipped S binding")
	if _fails.is_empty():
		print("MAIN MENU OK: splash, buttons, Play target and the options round-trip hold")
	else:
		for failure in _fails:
			printerr("main menu said no: ", failure)
	get_tree().quit(_fails.size())


func _round_trip() -> void:
	_panel.set_fullscreen(true)
	_panel.set_key("cue_draw", "A")
	_check(_seen_fullscreen, "display_mode_changed did not fire")
	_check(_seen_action == "cue_draw" and _seen_key == "A", "input_remapped did not carry the action and key")
	_panel.save_options()
	_check(FileAccess.file_exists(CONFIG_PATH), "options file was not written")
	var disk := ConfigFile.new()
	_check(disk.load(CONFIG_PATH) == OK, "options file did not load")
	_check(bool(disk.get_value("display", "fullscreen", false)), "fullscreen was not saved")
	_check(str(disk.get_value("input", "cue_draw", "")) == "A", "remap was not saved")
	_panel.set_fullscreen(false)
	_panel.set_key("cue_draw", "S")
	_check(not _panel.get_fullscreen(), "in-memory display mode was not cleared")
	_check(_panel.get_key("cue_draw") == "S", "in-memory remap was not cleared")
	_panel.load_options()
	_check(_panel.get_fullscreen(), "fullscreen did not survive the reload")
	_check(_panel.get_key("cue_draw") == "A", "remap did not survive the reload")


func _on_display_mode_changed(fullscreen: bool) -> void:
	_seen_fullscreen = fullscreen


func _on_input_remapped(action: String, key_label: String) -> void:
	_seen_action = action
	_seen_key = key_label


func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails.append(message)
