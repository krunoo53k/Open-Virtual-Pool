class_name MatchJudge
extends RefCounted

## The ruling half of one shot: ask EightBallRules, fold the Judgement into the
## composer's state and rack, then let TurnFlow advance. The rules decide;
## nothing here simulates, samples a path or stores a global.

static func apply_and_advance(flow: TurnFlow, rules: EightBallRules, simulation: PoolSimulation,
		shot: PoolShot, outcome: ShotOutcome, params: ShotParams, state: MatchState,
		rack: RackState, rack_view: BallRack) -> int:
	var ruling: Judgement = rules.judge_and_announce(outcome, params,
		simulation.events_of(shot, rack), state)
	var removed := outcome.pocketed.duplicate()
	removed.append_array(outcome.off_table)
	RulingApply.apply(state, ruling, removed)
	if ruling.re_rack:
		RackModel.rerack(rack_view, rack)
	else:
		RackModel.after_shot(shot, removed, rack)
	BallRackView.apply_state(rack_view, rack)
	if ruling.game_over:
		flow.go_to("GameOver")
		return ruling.winner
	if ruling.ball_in_hand:
		flow.go_to("BallInHand")
	else:
		flow.activate(state.player)
	return 0
