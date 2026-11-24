extends Node
class_name MatchFlow

## Sequences one match through TurnFlow's six phases. It owns the phase work:
## a stroke resolves through the adapter, the replay's end triggers the ruling,
## and the ruling chooses the next phase. The Match composer only wires it.

signal turn_changed(player: int)
signal match_finished(winner: int)
signal judgement_made(ruling: Judgement)
signal shot_resolved(log: ShotLog)

@export var flow: TurnFlow
@export var rules: EightBallRules
@export var playback: ShotPlayback
@export var rack_view: BallRack
@export var simulation: PoolSimulation
@export var ball_in_hand_input: BallInHandInput

var state: MatchState
var rack: RackState
var _shooters: Array[Node] = []

var _winner := 0
var _shot  # PoolShot, the path under replay.
var _outcome: ShotOutcome
var _params: ShotParams


func bind(match_state: MatchState, rack_state: RackState, shooters: Array[Node]) -> void:
	state = match_state
	rack = rack_state
	_shooters = shooters
	flow.phase_entered.connect(_on_phase)
	playback.path_finished.connect(_on_path_finished)


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


func get_winner() -> int:
	return _winner


func _on_phase(phase: String, player: int) -> void:
	# Only AwaitingShot accepts a stroke: a key held during a roll or a
	# placement would otherwise charge a shot the guard silently drops.
	for shooter in _shooters:
		shooter.set_process_unhandled_input(phase == "AwaitingShot")
	if ball_in_hand_input != null and phase != "BallInHand":
		ball_in_hand_input.deactivate()
	# The replay only belongs to the roll. Every other phase shows the live
	# rack: ball-in-hand places against the current layout, never against the
	# last shot's frozen positions, and game over keeps the settled table.
	var show_rack := phase == "AwaitingShot" or phase == "BallInHand" or phase == "GameOver"
	rack_view.visible = show_rack
	playback.visible = not show_rack
	match phase:
		"AwaitingShot":
			turn_changed.emit(player)
		"Striking":
			_shot = simulation.resolve(_params, rack)
			_outcome = simulation.outcome_of(_shot)
			# Snapshot while the rack is still the one the core was handed:
			# the ruling folds it forward into the final frame moments later.
			shot_resolved.emit(ShotLog.capture(simulation, _params, rack,
				_shot, _outcome, simulation.events_of(_shot, rack), player))
			playback.play(_shot, rack)
			flow.go_to("Rolling")
		"Judging":
			var ruling := MatchJudge.judge_and_apply(rules, simulation,
				_shot, _outcome, _params, state, rack, rack_view)
			judgement_made.emit(ruling)
			if ruling.game_over:
				_winner = ruling.winner
				flow.go_to("GameOver")
				match_finished.emit(_winner)
			elif ruling.ball_in_hand:
				flow.go_to("BallInHand")
			else:
				flow.activate(state.player)
		"BallInHand":
			if ball_in_hand_input != null:
				ball_in_hand_input.activate()


## The placement scene's public event: fold the chosen spot into the rack and
## resume the incoming player. The input never starts the shot flow itself.
func apply_cue_placement(position: Vector3) -> void:
	if flow.get_phase() != "BallInHand":
		return
	# place_at already checked this, but re-check at the writing end so any
	# other emitter of the signal cannot fold an illegal spot into the rack.
	if ball_in_hand_input != null and not CuePlacement.is_legal(position,
			ball_in_hand_input.layout, rack, ball_in_hand_input.tolerance):
		return
	RackModel.respot_cue(rack, position)
	BallRackView.place_cue(rack_view, position)
	if ball_in_hand_input != null:
		ball_in_hand_input.deactivate()
	flow.activate(state.player)


func _on_path_finished(_path) -> void:
	if flow.get_phase() == "Rolling":
		flow.go_to("Judging")
