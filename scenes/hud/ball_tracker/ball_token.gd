class_name BallToken
extends TextureRect

## A single numbered object ball. Display only: it knows nothing about rules.

@export var ball_number: int = 1

var _potted := false


func set_ball(number: int, texture: Texture2D) -> void:
	ball_number = number
	self.texture = texture
	set_potted(false)


func set_potted(potted: bool) -> void:
	_potted = potted
	modulate = Color(0.26, 0.30, 0.27, 0.65) if potted else Color(1, 1, 1, 1)
	tooltip_text = "Ball %d — %s" % [ball_number, "potted" if potted else "on the table"]


func is_potted() -> bool:
	return _potted
