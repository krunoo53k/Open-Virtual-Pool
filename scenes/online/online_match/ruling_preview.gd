class_name RulingPreview
extends RefCounted

## Display-only ruling preview while the local prediction plays. It never
## mutates the live MatchState and never decides the match: COMMIT always wins.
##
## The engine's shared Rust judge is used as soon as the loaded extension
## exposes `preview_shot_json` (its request/response shape is documented in
## the engine's `pool-godot/src/bridge_json.rs`). Until a rebuilt `.so` with
## that method is installed, the existing pure GDScript judge runs on a
## duplicate state — display-only, no new rule decision. GDScript
## `EightBallRules` is retired once the engine judge is shipped and pinned.

static func preview_from_shot(simulation: PoolSimulation, shot: PoolShot,
		params_wire: Dictionary, rack: RackState, state: MatchState) -> Judgement:
	var outcome := simulation.outcome_of(shot)
	var core = simulation.core
	if core != null and core.has_method("preview_shot_json"):
		var request := {
			"numbers": Array(rack.numbers),
			"events": shot.get_events(),
			"state": {
				"phase": outcome.phase,
				"foul": outcome.foul,
				"miscue": outcome.miscue,
				"elapsed_time": outcome.elapsed_time,
			},
			"params": params_wire,
			"match": {
				"player": state.player,
				"solids_player": state.solids_player,
				"remaining": Array(state.remaining),
				"ball_in_hand": state.ball_in_hand,
				"break_next": state.break_next,
			},
			"error": outcome.error,
		}
		var raw: Variant = JSON.parse_string(String(core.preview_shot_json(
			JSON.stringify(request, "", false, true))))
		if raw is Dictionary and (raw as Dictionary).has("judgement"):
			return _from_dict(raw["judgement"])
	# Provisional fallback: the pure judge on a duplicate, never the live state.
	var rules := EightBallRules.new()
	return rules.judge(outcome, params_from_wire(params_wire),
		simulation.events_of(shot, rack), state.duplicate())


static func params_from_wire(data: Dictionary) -> ShotParams:
	var params := ShotParams.new()
	params.speed = float(data.get("speed", 8.0))
	params.level_aim_deg = float(data.get("level_aim_deg", 90.0))
	params.elevation_deg = float(data.get("elevation_deg", 0.0))
	params.contact_x = float(data.get("contact_x", 0.0))
	params.contact_y = float(data.get("contact_y", 0.0))
	params.called_pocket = int(data.get("called_pocket", -1))
	return params


static func _from_dict(raw: Dictionary) -> Judgement:
	var ruling := Judgement.new()
	ruling.foul_reason = String(raw.get("foul_reason", ""))
	ruling.next_player = clampi(int(raw.get("next_player", raw.get("player", 1))), 1, 2)
	ruling.ball_in_hand = bool(raw.get("ball_in_hand", false))
	ruling.re_rack = bool(raw.get("re_rack", false))
	ruling.solids_player = clampi(int(raw.get("solids_player", 0)), 0, 2)
	ruling.game_over = bool(raw.get("game_over", false))
	ruling.winner = clampi(int(raw.get("winner", 0)), 0, 2)
	return ruling
