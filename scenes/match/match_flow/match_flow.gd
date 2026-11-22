extends Node
class_name MatchFlow

## Sequences one match through TurnFlow's six phases. It owns the phase work:
## a stroke resolves through the adapter, the replay's end triggers the ruling,
## and the ruling chooses the next phase. The Match composer only wires it.

signal turn_changed(player: int)
signal match_finished(winner: int)

@export var flow: TurnFlow
@export var rules: EightBallRules
@export var playback: ShotPlayback
@export var rack_view: BallRack
@export var simulation: PoolSimulation

var state: MatchState
var rack: RackState
var winner := 0

var _layout: TableLayout
var _shot  # PoolShot, the path under replay.
var _outcome: ShotOutcome
var _params: ShotParams


func bind(match_state: MatchState, rack_state: RackState) -> void:
	state = match_state
	rack = rack_state
	flow.phase_entered.connect(_on_phase)
	playback.path_finished.connect(_on_path_finished)


func set_layout(value: TableLayout) -> void:
	_layout = value


func begin() -> void:
	flow.activate(1)


func take_shot(params: ShotParams) -> void:
	if not flow.is_awaiting_shot():
		return
	_params = params
	state.ball_in_hand = false
	flow.go_to("Striking")


func get_phase() -> String:
	return flow.get_phase()


func get_current_player() -> int:
	return state.player


func _on_phase(phase: String, player: int) -> void:
	match phase:
		"AwaitingShot":
			rack_view.visible = true
			playback.visible = false
			turn_changed.emit(player)
		"Striking":
			_shot = simulation.resolve(_params, rack)
			_outcome = simulation.outcome_of(_shot)
			rack_view.visible = false
			playback.visible = true
			playback.play(_shot, rack)
			flow.go_to("Rolling")
		"Judging":
			var won := MatchJudge.apply_and_advance(flow, rules, simulation,
				_shot, _outcome, _params, state, rack, rack_view)
			if won != 0:
				winner = won
				match_finished.emit(won)
		"BallInHand":
			# #7's neutral head-spot; #8 replaces it with mouse placement.
			var spot := RackModel.head_spot(_layout)
			RackModel.respot_cue(rack, spot)
			BallRackView.place_cue(rack_view, spot)
			flow.activate(state.player)


func _on_path_finished(_path) -> void:
	if flow.get_phase() == "Rolling":
		flow.go_to("Judging")
