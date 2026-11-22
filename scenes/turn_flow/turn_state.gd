extends Node
class_name TurnState

## One phase of the match's turn. The state holds no logic: entering it
## announces that the match is there, and the composer does the work the
## phase asks for. Six of these sit under TurnFlow, one per named phase.

signal activated(phase: String)

@export var phase := ""

func enter() -> void:
	activated.emit(phase)
