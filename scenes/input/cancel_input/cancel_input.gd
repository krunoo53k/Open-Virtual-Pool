
extends Node3D
class_name CancelInput

## CancelInput: Esc forgets the stroke in progress, the same as letting go
## of the key. The binding is the shared table's; noticing the press is
# this leaf's, and what forgetting a stroke means is StrokeInput's.

signal cancel_requested()

func _ready() -> void:
	# This leaf also runs standalone in the editor; do not depend on a
	# sibling having registered the shared actions first.
	InputActions.register_defaults()


func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("cancel"):
		cancel_requested.emit()
