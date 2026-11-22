class_name BootSplash
extends Control

## The brief title card shown when the menu starts. It owns only its own
## subtree and hides itself on a Timer, so a headless run is never held up.

signal splash_finished

@export var display_duration: float = 1.2

@onready var _timer: Timer = $Timer

var _running := false


func _ready() -> void:
	_timer.timeout.connect(hide_splash)
	show_splash()


func show_splash() -> void:
	show()
	_running = true
	_timer.start(display_duration)


func hide_splash() -> void:
	if not _running:
		return
	_running = false
	_timer.stop()
	hide()
	splash_finished.emit()
