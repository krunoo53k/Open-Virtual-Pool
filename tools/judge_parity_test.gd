extends Node

## Rule parity: every canonical fixture is judged twice — once by the legacy
## GDScript EightBallRules and once by the engine's shared Rust judge through
## `preview_shot_json`. The fields must agree exactly before the GDScript judge
## can be retired. Exit code = number of disagreeing shots.

const FIXTURES := "res://fixtures/eight_ball_fixtures.json"
const FIELDS := ["foul_reason", "next_player", "ball_in_hand", "re_rack",
	"solids_player", "game_over", "winner"]

var _fails := 0
var _shots := 0
var _core


func _ready() -> void:
	_core = PoolCore.new()
	var file := FileAccess.open(FIXTURES, FileAccess.READ)
	if file == null:
		printerr("parity: cannot open ", FIXTURES)
		get_tree().quit(1)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("fixtures"):
		printerr("parity: fixtures unreadable")
		get_tree().quit(1)
		return
	var rules := EightBallRules.new()
	for fixture in parsed["fixtures"]:
		_run_fixture(fixture, rules)
	if _fails == 0:
		print("JUDGE PARITY OK: ", _shots, " shots agree with the engine judge")
	else:
		printerr("judge parity: ", _fails, " of ", _shots, " shots disagree")
	get_tree().quit(_fails)


func _run_fixture(fixture: Dictionary, rules: EightBallRules) -> void:
	var state := MatchState.new()
	state.player = 1
	state.break_next = true
	state.remaining = _full_rack()
	for shot in fixture["shots"]:
		_shots += 1
		var params := ShotParams.new()
		params.called_pocket = int(shot["params"].get("called_pocket", -1))
		var outcome := ShotOutcome.new()
		var words := {"solved": "settled", "settling": "settling"}
		outcome.phase = words.get(String(shot["outcome"].get("outcome_of", "")), "faulted")
		outcome.miscue = bool(shot["outcome"].get("miscue", false))
		outcome.foul = bool(shot["outcome"].get("foul", false))
		var events: Array[ShotEvent] = []
		for d in shot["events"]:
			var event := ShotEvent.new()
			event.kind = String(d["kind"])
			event.ball = int(d["ball"])
			event.other = int(d["other"])
			event.time = float(d["time"])
			event.detail = int(d.get("detail", 0))
			events.append(event)
		var gd := rules.judge(outcome, params, events, state)
		var rust := _engine_judge(outcome, params, events, state)
		if rust.is_empty():
			_fails += 1
			printerr("  FAIL: ", shot["name"], " — engine judge returned no ruling")
		else:
			for field in FIELDS:
				if gd.get(field) != rust.get(field):
					_fails += 1
					printerr("  FAIL: ", shot["name"], " ", field, " gd=", gd.get(field),
						" rust=", rust.get(field))
		if gd.game_over:
			break
		var potted: Array[int] = []
		for event in events:
			if event.kind == "pocket-drop" and event.ball != 0:
				potted.append(event.ball)
		state.player = gd.next_player
		state.ball_in_hand = gd.ball_in_hand
		if gd.solids_player != 0:
			state.solids_player = gd.solids_player
		state.break_next = gd.re_rack
		if gd.re_rack:
			state.remaining = _full_rack()
		else:
			var remaining: Array[int] = []
			for n in state.remaining:
				if not potted.has(n):
					remaining.append(n)
			state.remaining = remaining


func _engine_judge(outcome: ShotOutcome, params: ShotParams,
		events: Array[ShotEvent], state: MatchState) -> Dictionary:
	var wire_events: Array = []
	for event in events:
		wire_events.append({
			"time": event.time,
			"kind": event.kind,
			# Identity numbers make ball number == index; 255 is "no index".
			"a": event.ball if event.ball >= 0 else 255,
			"b": event.other if event.other >= 0 else 255,
			"detail": event.detail,
		})
	var request := {
		"numbers": range(16),
		"events": wire_events,
		"state": {
			"phase": outcome.phase,
			"foul": outcome.foul,
			"miscue": outcome.miscue,
			"elapsed_time": outcome.elapsed_time,
		},
		"params": {
			"speed": params.speed, "level_aim_deg": params.level_aim_deg,
			"elevation_deg": params.elevation_deg, "contact_x": params.contact_x,
			"contact_y": params.contact_y, "called_pocket": params.called_pocket,
		},
		"match": {
			"player": state.player, "solids_player": state.solids_player,
			"remaining": Array(state.remaining), "ball_in_hand": state.ball_in_hand,
			"break_next": state.break_next,
		},
		"error": outcome.error,
	}
	var raw: Variant = JSON.parse_string(String(_core.preview_shot_json(
		JSON.stringify(request, "", false, true))))
	if not (raw is Dictionary) or not (raw as Dictionary).has("judgement"):
		return {}
	return raw["judgement"]


func _full_rack() -> Array[int]:
	var out: Array[int] = []
	for i in range(1, 16):
		out.append(i)
	return out
