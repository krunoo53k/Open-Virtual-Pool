extends Node
class_name ShotLogInput

## The debug bind: L asks for the last shot to be written out. This leaf only
## notices the press and emits intent; the writing is ShotDebugLog's job.

signal log_requested()


func _ready() -> void:
	InputActions.register_defaults()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("dump_shot_log"):
		log_requested.emit()
