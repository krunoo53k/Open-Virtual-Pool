extends Node

## Headless acceptance harness for issue #9: replay the BCA fixtures through
## real EightBallRules and real Hud, assert the HUD after every ruling, then
## drive ui_left / ui_right / ui_accept through the pocket picker. The exit
## code is the number of failed assertions.

const FIXTURES := "res://fixtures/eight_ball_fixtures.json"

var _hud: Hud
var _rules: EightBallRules
var _turn: TurnStatus
var _foul: FoulBanner
var _result: ResultBanner
var _picker: CalledPocketPicker
var _pause: PauseMenu
var _pockets: Array[int] = []
var _intents: Array[String] = []
var _eight_state: MatchState
var _fails := 0
var _shots := 0

func _ready() -> void:
	_hud = $Hud
	_rules = $Rules
	_turn = $Hud/TurnStatus
	_foul = $Hud/FoulBanner
	_result = $Hud/ResultBanner
	_picker = $Hud/CalledPocketPicker
	_pause = $Hud/PauseMenu
	_rules.foul_committed.connect(_hud.on_foul_committed)
	_hud.pocket_called.connect(_on_pocket)
	_hud.resume_requested.connect(func(): _intents.append("resume"))
	_hud.restart_requested.connect(func(): _intents.append("restart"))
	_hud.menu_requested.connect(func(): _intents.append("menu"))
	var file := FileAccess.open(FIXTURES, FileAccess.READ)
	if file == null:
		printerr("hud-test: fixtures unreadable")
		get_tree().quit(1)
		return
	for fixture in JSON.parse_string(file.get_as_text())["fixtures"]:
		_run(fixture)
	await _check_picker()
	_check(String($Hud/VersionStamp/Label.text).begins_with("core model "), "version stamp")
	print("hud-test: %d failures in %d rulings" % [_fails, _shots])
	get_tree().quit(_fails)

func _check(ok: bool, why: String) -> void:
	if not ok:
		_fails += 1
		printerr("hud-test said no: ", why)

func _on_pocket(index: int) -> void:
	_pockets.append(index)

func _run(fixture: Dictionary) -> void:
	var state := MatchState.new()
	state.remaining = PackedInt32Array(range(1, 16))
	state.break_next = true
	for shot in fixture["shots"]:
		_shots += 1
		var made := _mk(shot)
		var ruling: Judgement = _rules.judge_and_announce(made.outcome, made.params, made.events, state)
		_hud.show_judgement(ruling)
		_check(_foul.reason_text() == ruling.foul_reason, String(shot["name"]) + ": foul reason")
		_check(_result.result_text() == ("" if not ruling.game_over else "player %d wins!" % ruling.winner), String(shot["name"]) + ": result")
		if ruling.game_over:
			return
		var potted: Array[int] = []
		for e in made.events:
			if e.kind == "pocket-drop" and e.ball != 0:
				potted.append(e.ball)
		state.player = ruling.next_player
		state.ball_in_hand = ruling.ball_in_hand
		if ruling.solids_player != 0:
			state.solids_player = ruling.solids_player
		state.break_next = ruling.re_rack
		state.remaining = PackedInt32Array(Array(state.remaining).filter(func(n): return ruling.re_rack or not potted.has(n)))
		_hud.show_state(state)
		_assert(state, String(shot["name"]))

func _assert(state: MatchState, name: String) -> void:
	_check(_turn.turn_text() == "player %d to shoot" % state.player, name + ": turn")
	_check(_turn.group_text(1) == _tag(state, 1) and _turn.group_text(2) == _tag(state, 2), name + ": groups")
	_check(_turn.remaining_text() == "remaining: %d" % state.remaining.size(), name + ": remaining")
	var eight := _on_eight(state)
	if eight:
		_eight_state = state.duplicate() as MatchState
	_check(_picker.visible == eight, name + ": picker")

func _mk(shot: Dictionary) -> Dictionary:
	var p := ShotParams.new()
	p.called_pocket = int(shot["params"].get("called_pocket", -1))
	var o := ShotOutcome.new()
	o.phase = {"solved": "settled", "settling": "settling"}.get(String(shot["outcome"].get("outcome_of", "")), "faulted")
	o.miscue = bool(shot["outcome"].get("miscue", false))
	o.foul = bool(shot["outcome"].get("foul", false))
	var evs: Array[ShotEvent] = []
	for d in shot["events"]:
		var e := ShotEvent.new()
		e.kind = String(d["kind"])
		e.ball = int(d["ball"])
		e.other = int(d["other"])
		e.time = float(d["time"])
		evs.append(e)
	return {"params": p, "outcome": o, "events": evs}

func _tag(state: MatchState, player: int) -> String:
	if state.solids_player == 0:
		return "open"
	return "solids" if state.solids_player == player else "stripes"

func _on_eight(state: MatchState) -> bool:
	if state.solids_player == 0 or not state.remaining.has(8):
		return false
	for n in state.remaining:
		if n != 8 and (n <= 7) == (state.solids_player == state.player):
			return false
	return true

func _check_picker() -> void:
	_check(_eight_state != null, "no fixture put the shooter on the 8")
	_hud.show_state(_eight_state if _eight_state != null else MatchState.new())
	_check(_picker.visible, "picker hidden while shooting for the 8")
	for action in ["ui_right", "ui_right", "ui_accept", "ui_left", "ui_accept"]:
		await _press(action)
	_check(_pockets.size() == 2 and _pockets[0] == 2 and _pockets[1] == 1, "keyboard call order")
	_hud.set_called_pocket(5)
	_check(_picker.selected_index() == 5, "set_called_pocket did not move the highlight")
	_hud.toggle_pause()
	_check(_pause.is_open(), "toggle_pause did not open the menu")
	_hud.toggle_pause()
	_check(not _pause.is_open(), "toggle_pause did not close the menu")
	for choice in ["Resume", "Restart", "BackToMenu"]:
		(_hud.get_node("PauseMenu/Choices/" + choice) as Button).pressed.emit()
	_check(_intents == ["resume", "restart", "menu"], "pause intents")

func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
