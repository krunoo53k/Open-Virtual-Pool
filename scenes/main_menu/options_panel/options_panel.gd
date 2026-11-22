class_name OptionsPanel
extends Control

## Display mode plus the input remap list, persisted to a ConfigFile. It edits
## only its own subtree and reports every change with a typed signal.

signal display_mode_changed(fullscreen: bool)
signal input_remapped(action: String, key_label: String)
signal back_requested

const CONFIG_PATH := "user://open_virtual_pool.cfg"

@onready var _display: OptionButton = $Panel/Margin/VBox/DisplayRow/DisplayMode
@onready var _remaps: RemapList = $Panel/Margin/VBox/RemapList

var _fullscreen := false
var _syncing := false
var _config := ConfigFile.new()


func _ready() -> void:
	_display.add_item("Windowed")
	_display.add_item("Fullscreen")
	_display.item_selected.connect(_on_display_selected)
	_remaps.key_changed.connect(_on_key_changed)
	$Panel/Margin/VBox/Back.pressed.connect(_on_back_pressed)
	load_options()


func _on_display_selected(index: int) -> void:
	set_fullscreen(index == 1)
	save_options()


func _on_key_changed(action: String, label: String) -> void:
	input_remapped.emit(action, label)
	if not _syncing:
		save_options()


func _on_back_pressed() -> void:
	back_requested.emit()


func set_fullscreen(value: bool) -> void:
	_fullscreen = value
	_display.set_block_signals(true)
	_display.select(1 if value else 0)
	_display.set_block_signals(false)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
	display_mode_changed.emit(value)


func get_fullscreen() -> bool:
	return _fullscreen


func set_key(action: String, label: String) -> void:
	_syncing = true
	_remaps.set_key(action, label)
	_syncing = false


func get_key(action: String) -> String:
	return _remaps.get_key(action)


func save_options() -> void:
	_config.set_value("display", "fullscreen", _fullscreen)
	for action in RemapList.ACTIONS:
		_config.set_value("input", action, get_key(action))
	var err := _config.save(CONFIG_PATH)
	if err != OK:
		push_warning("Could not save options: %s (%d)" % [CONFIG_PATH, err])


func load_options() -> void:
	if _config.load(CONFIG_PATH) != OK:
		return
	set_fullscreen(bool(_config.get_value("display", "fullscreen", false)))
	for action in RemapList.ACTIONS:
		var label := str(_config.get_value("input", action, ""))
		if not label.is_empty():
			set_key(action, label)
