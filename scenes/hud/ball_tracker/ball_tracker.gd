class_name BallTracker
extends PanelContainer

## Shows all fifteen object balls grouped as solids / eight / stripes and
## dims the ones no longer on the table. Reads MatchState; decides nothing.

@export var ball_textures: Array[Texture2D] = []

var _tokens: Array[BallToken] = []


func _ready() -> void:
	for row in [$Margin/VBox/SolidsRow, $Margin/VBox/EightRow, $Margin/VBox/StripesRow]:
		for child in (row as HBoxContainer).get_children():
			if child is BallToken:
				_tokens.append(child)
	for i in range(1, 16):
		_tokens[i - 1].set_ball(i, ball_textures[i])


func show_state(state: MatchState) -> void:
	for i in range(1, 16):
		_tokens[i - 1].set_potted(not state.remaining.has(i))


func is_potted(number: int) -> bool:
	return _tokens[number - 1].is_potted()
