class_name MatchJudge
extends RefCounted

## The ruling half of one shot: ask EightBallRules, fold the Judgement into the
## composer's state and rack, and hand the ruling back. The rules decide;
## nothing here simulates, samples a path or stores a global. MatchFlow owns
## the phase transitions that follow, so the composer can see the Judgement.

static func judge_and_apply(rules: EightBallRules, simulation: PoolSimulation,
		shot: PoolShot, outcome: ShotOutcome, params: ShotParams, state: MatchState,
		rack: RackState, rack_view: BallRack) -> Judgement:
	var ruling: Judgement = rules.judge_and_announce(outcome, params,
		simulation.events_of(shot, rack), state)
	var removed := outcome.pocketed.duplicate()
	removed.append_array(outcome.off_table)
	RulingApply.apply(state, ruling, removed)
	RackModel.after_shot(shot, removed, rack)
	BallRackView.apply_state(rack_view, rack)
	return ruling
