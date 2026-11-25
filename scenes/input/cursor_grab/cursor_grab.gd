extends Node
class_name CursorGrab

## Owns the mouse mode for one match. A grabbed cursor keeps reporting
## relative motion past the window edge, so a long aim turn does not stop at
## the border. It reads no gameplay state: the composer says which phase is
## live and whether a menu has the pointer, and this scene only applies it.

var _phase := ""
var _ui_open := false
var _grabbed := false


func set_phase(phase: String, _player: int = -1) -> void:
	_phase = phase
	_apply()


func set_ui_open(open: bool) -> void:
	_ui_open = open
	_apply()


func is_grabbed() -> bool:
	return _grabbed


func _apply() -> void:
	# A menu or the result screen needs a visible pointer; every other phase
	# is play, where the drag must keep coming past the window border.
	var grabbed := not _ui_open and _phase != "" and _phase != "GameOver"
	if grabbed == _grabbed:
		return
	_grabbed = grabbed
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if grabbed else Input.MOUSE_MODE_VISIBLE)


func _exit_tree() -> void:
	if _grabbed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_grabbed = false
