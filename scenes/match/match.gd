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
var _called_pocket := -1


func _ready() -> void:
	var sim: PoolSimulation = simulation_scene.instantiate()
	sim.name = "Simulation"
	add_child(sim)
	var layout: TableLayout = sim.layout
	$BallRack.set_geometry({"length": layout.length, "width": layout.width,
		"ball_radius": layout.ball_radius})
	$BallRack.rebuild()
	rack.numbers = $BallRack.get_numbers()
	rack.positions = $BallRack.get_positions(); rack.rotations = $BallRack.get_orientations()
	$BallInHandInput.layout = layout
	$BallInHandInput.rack = rack
	state.remaining = RulingApply.full_rack()
	$Shooter1.core = sim
	$Shooter2.core = sim
	$Shooter1.shot_committed.connect(_on_shot_committed.bind(1))
	$Shooter2.shot_committed.connect(_on_shot_committed.bind(2))
	var sequence = $MatchFlow
	sequence.flow = $TurnFlow
	sequence.rules = $Rules
	sequence.playback = $ShotPlayback
	sequence.rack_view = $BallRack
	sequence.simulation = sim
	sequence.ball_in_hand_input = $BallInHandInput
	var shooters: Array[Node] = [$Shooter1, $Shooter2]
	sequence.bind(state, rack, shooters)
	sequence.turn_changed.connect(_on_turn_changed)
	sequence.match_finished.connect(match_finished.emit)
	sequence.judgement_made.connect($HudWiring.on_judgement)
	$BallInHandInput.cue_ball_placed.connect(sequence.apply_cue_placement)
	$HudWiring.wire($Hud, $Rules, state)
	$HudWiring.pocket_called.connect(func(index: int): _called_pocket = index)
	sequence.begin()


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
	return $MatchFlow.get_winner()


func _on_shot_committed(params: ShotParams, player: int) -> void:
	if player == $TurnFlow.get_active_player():
		params.called_pocket = _called_pocket
		_called_pocket = -1
		take_shot(params)


func _on_turn_changed(player: int) -> void:
	$Shooter1.rearm_after_the_settle()
	$Shooter2.rearm_after_the_settle()
	turn_changed.emit(player)
