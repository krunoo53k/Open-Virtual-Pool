class_name CalledPocketPicker
extends PanelContainer

## Six-pocket picker for the 8-ball call. Core order: 0-3 corners, then 4-5
## sides. ui_left / ui_right move the highlight, ui_accept calls the pocket;
## which pockets exist and what a call means are the rules' business, not this
## view's. It only announces the index the player highlighted.

signal pocket_called(index: int)

const POCKET_NAMES := ["TL", "TR", "BL", "BR", "LS", "RS"]

var _selected := 0

func _ready() -> void:
	_highlight()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var count := POCKET_NAMES.size()
	if event.is_action_pressed("ui_left"):
		set_selection((_selected + count - 1) % count)
	elif event.is_action_pressed("ui_right"):
		set_selection((_selected + 1) % count)
	elif event.is_action_pressed("ui_accept"):
		pocket_called.emit(_selected)


func set_selection(index: int) -> void:
	_selected = index if index >= 0 and index < POCKET_NAMES.size() else 0
	_highlight()


func selected_index() -> int:
	return _selected


func _highlight() -> void:
	for i in POCKET_NAMES.size():
		var label := get_node("Rows/Pockets/Pocket%d" % i) as Label
		label.modulate = Color.YELLOW if i == _selected else Color.WHITE
	$Rows/SelectionLabel.text = "called: %s (%d)" % [POCKET_NAMES[_selected], _selected]
