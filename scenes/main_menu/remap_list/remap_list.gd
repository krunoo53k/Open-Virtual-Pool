class_name RemapList
extends Control

## A compact action -> key picker. It emits the intent to remap; it does not
## know who persists it or which screen contains it.

signal key_changed(action: String, key_label: String)

const ACTIONS := ["cue_draw", "fine_trim", "english_hold", "camera_toggle"]

var _options: Dictionary = {}


func _ready() -> void:
	InputActions.register_defaults()
	for row in $Rows.get_children():
		var action: String = row.get_meta("action")
		var option := row.get_node("KeyOption") as OptionButton
		for label in InputRemap.KEY_LABELS:
			option.add_item(str(label))
		_options[action] = option
		var index := InputRemap.KEY_LABELS.find(InputRemap.label_for_action(action))
		if index >= 0:
			option.select(index)
		option.item_selected.connect(_on_key_selected.bind(action))


func _on_key_selected(index: int, action: String) -> void:
	var label: String = str(InputRemap.KEY_LABELS[index])
	InputRemap.apply(action, label)
	key_changed.emit(action, label)


func set_key(action: String, label: String) -> void:
	var option: OptionButton = _options.get(action)
	if option == null:
		return
	var index := InputRemap.KEY_LABELS.find(label)
	if index >= 0:
		option.set_block_signals(true)
		option.select(index)
		option.set_block_signals(false)
		InputRemap.apply(action, label)
		key_changed.emit(action, label)


func get_key(action: String) -> String:
	var option: OptionButton = _options.get(action)
	if option == null or option.selected < 0:
		return ""
	return str(InputRemap.KEY_LABELS[option.selected])
