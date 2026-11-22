extends Node3D
class_name Match

## The match composer: it owns the MatchState and RackState, instances the
## swappable adapter, wires the typed scenes to MatchFlow, and forwards its
## events. It never rules a shot, samples a path or builds a scene tree.

signal turn_changed(player: int)
signal match_finished(winner: int)

@export var simulation_scene: PackedScene

var state := MatchState.new()
var rack := RackState.new()


func _ready() -> void:
	var sim: PoolSimulation = simulation_scene.instantiate()
	sim.name = "Simulation"
	add_child(sim)
	var layout: TableLayout = sim.layout
	$BallRack.set_geometry({"length": layout.length, "width": layout.width,
		"ball_radius": layout.ball_radius})
	$BallRack.rebuild()
	rack.numbers = $BallRack.get_numbers()
	rack.positions = $BallRack.get_positions()
	rack.rotations = $BallRack.get_orientations()
	state.remaining = RulingApply.full_rack()
	_wire_shooters(sim)
	var sequence = $MatchFlow
	sequence.flow = $TurnFlow
	sequence.rules = $Rules
	sequence.playback = $ShotPlayback
	sequence.rack_view = $BallRack
	sequence.simulation = sim
	sequence.set_layout(layout)
	sequence.bind(state, rack)
	sequence.turn_changed.connect(_on_turn_changed)
	sequence.match_finished.connect(match_finished.emit)
	sequence.begin()


func _wire_shooters(sim: PoolSimulation) -> void:
	$Shooter1.core = sim
	$Shooter2.core = sim
	$Shooter1.shot_committed.connect(_on_shot_committed.bind(1))
	$Shooter2.shot_committed.connect(_on_shot_committed.bind(2))
	InputActions.register_defaults()


## The same entry a scripted player, an AI or a netcode peer calls.
func take_shot(params: ShotParams) -> void:
	$MatchFlow.take_shot(params)


func get_phase() -> String:
	return $MatchFlow.get_phase()


func get_current_player() -> int:
	return $MatchFlow.get_current_player()


func get_state() -> MatchState:
	return state


func get_winner() -> int:
	return $MatchFlow.winner


func _on_shot_committed(params: ShotParams, player: int) -> void:
	if player == $TurnFlow.get_active_player():
		take_shot(params)


func _on_turn_changed(player: int) -> void:
	$Shooter1.rearm_after_the_settle()
	$Shooter2.rearm_after_the_settle()
	$HudLayer/TurnBadge.text = "Player %d to shoot" % player
	turn_changed.emit(player)
