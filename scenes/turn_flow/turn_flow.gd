extends Node
class_name TurnFlow

## The match's phases as six child state nodes, not a phase enum in _process.
## This scene only owns WHICH phase and WHICH player are current: it announces
## every entry and leaves the shot, the ruling and the rack to the composer.
## activate(player) is the hotseat switch an AI or netcode player will use too.

signal phase_entered(phase: String, player: int)
signal player_activated(player: int)

const PHASES := ["AwaitingShot", "Striking", "Rolling", "Judging", "BallInHand", "GameOver"]

var _phase := "AwaitingShot"
var _player := 1

func _ready() -> void:
	for child in get_children():
		if child is TurnState:
			child.activated.connect(_on_state_activated)


func activate(player: int) -> void:
	_player = player
	player_activated.emit(player)
	go_to("AwaitingShot")


func go_to(phase: String) -> void:
	assert(PHASES.has(phase), "unknown turn phase: " + phase)
	_phase = phase
	for child in get_children():
		if child is TurnState and child.phase == phase:
			child.enter()
			return


func get_phase() -> String:
	return _phase


func get_active_player() -> int:
	return _player


func is_awaiting_shot() -> bool:
	return _phase == "AwaitingShot"


func _on_state_activated(phase: String) -> void:
	phase_entered.emit(phase, _player)
