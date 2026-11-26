extends Node3D
class_name OnlineMatch

## Online composer. It reuses the hotseat Match scene wholesale - physics,
## playback, views, HUD and the local ruling preview are the same scenes - and
## only replaces the remote shooter, redirects local strokes to SHOT, and
## holds the Judging phase until the authoritative COMMIT arrives.
##
## Wire shapes expected from the server (see docs/online-multiplayer.md):
##   ROOM_STATE {seq, match, rack, remaining_time}
##   COMMIT     {seq, params, hash, outcome, events, judgement, match, rack,
##               duration, remaining_time}
##   match      {player, solids_player, remaining, ball_in_hand, break_next}
##   rack       {positions: flat core f64, numbers: ints, rotations: flat core f64}
##   judgement  {foul_reason, next_player, ball_in_hand, re_rack,
##               solids_player, game_over, winner}
##   AIM        {level_aim_deg, elevation_deg, english_x, english_y,
##               pull_m, speed_m_s}
##   PLACE_PREVIEW {place: {x, y}}  # core frame; cue z is the implied radius.
##
## No new physics and no new rule decisions live here: the server's outcome,
## events, judgement, rack and match are applied verbatim after validation.

signal finished(winner: int)

const MATCH_SCENE := "res://scenes/match/match.tscn"
const MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const REMOTE_SHOOTER_SCRIPT := preload("res://scenes/input/remote_shooter/remote_shooter.gd")
const AIM_INTERVAL := 1.0 / 15.0

var session  # NetworkSession (duck-typed so a harness can inject a double).
var seat := 0  # 0 = player 1 (breaks first), 1 = player 2.
var peer_name := ""
var match_node: Match

var _confirmed_seq := -1
var _confirmed_rack: RackState
var _confirmed_state: MatchState
var _last_rack_wire: Dictionary = {}
var _last_match_wire: Dictionary = {}
var _in_flight: Dictionary = {}  # seq -> prediction record.
var _commits := CommitQueue.new()
var _active_commit: Dictionary = {}
var _current_seq := -1
var _playing := false
## Set when the local replay has reached Judging and is holding for COMMIT.
## A commit that arrives after that point must be applied immediately, or the
## flow would stay in Judging forever (the signal fires only once).
var _judging_pending := false
var _winner := 0
var _remaining_time := 0.0
var _aim_clock := 0.0
var _pending_place: Dictionary = {}
var _latest_aim: Dictionary = {}
var _latest_place: Dictionary = {}
var _reconciled := true
var _error_message := ""


func _ready() -> void:
	if session == null:
		var handoff := OnlineHandoff.take_handoff()
		if handoff != null:
			session = handoff.get("session")
			seat = int(handoff.get("seat", 0))
			peer_name = String(handoff.get("peer_name", ""))
	var packed: PackedScene = load(MATCH_SCENE)
	match_node = packed.instantiate()
	# Replace exactly one shooter's script before _ready runs; the scene's
	# leaves stay in place, so the remote seat still satisfies AimView.
	var local_shooter = match_node.get_node("Shooter1" if seat == 0 else "Shooter2")
	var remote_shooter = match_node.get_node("Shooter2" if seat == 0 else "Shooter1")
	remote_shooter.set_script(REMOTE_SHOOTER_SCRIPT)
	# Online seams on the reused flow; hotseat keeps both off.
	var flow_node: MatchFlow = match_node.get_node("MatchFlow")
	flow_node.use_serialized_resolve = true
	flow_node.suppress_judging = true
	match_node.shot_sink = Callable(self, "_on_local_shot")
	var wiring: HudWiring = match_node.get_node("HudWiring")
	wiring.online_leave_sink = Callable(self, "leave_match")
	match_node.get_node("ShotPlayback").time_scale = 1.0
	add_child(match_node)

	match_node.match_finished.connect(_on_match_finished)
	flow_node.judgement_pending.connect(_on_judgement_pending)
	flow_node.shot_resolved.connect(_on_shot_resolved)
	match_node.get_node("TurnFlow").player_activated.connect(_on_player_activated)
	match_node.get_node("BallInHandInput").cue_ball_placed.connect(_on_local_place)
	local_shooter.aim_state_changed.connect(_on_local_aim_changed)
	if session != null:
		session.room_state.connect(_on_room_state)
		session.commit.connect(_on_commit)
		session.error_received.connect(_on_error)
		session.game_over.connect(_on_game_over)
		session.aim_received.connect(_on_aim)
		session.place_preview_received.connect(_on_place_preview)
		session.disconnected.connect(_on_disconnected)
	_set_status("waiting for ROOM_STATE")


func get_local_player() -> int:
	return seat + 1


func leave_match() -> void:
	# Leaving mid-match is the same forfeit as one deadline expiry.
	if session != null and session.has_method("send_leave"):
		session.call("send_leave")
	if ResourceLoader.exists(MENU_SCENE):
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		get_tree().quit(0)


func _process(delta: float) -> void:
	_aim_clock += delta
	_refresh_status()


# ---------------------------------------------------------------- local shot

func _on_local_shot(params: ShotParams, player: int) -> void:
	if player != get_local_player():
		return
	if match_node.get_phase() != "AwaitingShot":
		return
	if _confirmed_seq < 0:
		_set_status("waiting for the server before shooting")
		return
	var seq := _confirmed_seq + 1
	var params_wire := _wire(JSON.stringify(
		PoolSimulation.params_dict(params), "", false, true))
	var rack_wire := _wire(JSON.stringify(
		PoolSimulation.rack_dict(_confirmed_rack), "", false, true))
	var place: Dictionary = {}
	if _confirmed_state.ball_in_hand:
		place = _pending_place.duplicate(true)
		if place.is_empty():
			place = _place_to_wire(_confirmed_rack.get_position(
				_confirmed_rack.numbers.find(0)))
	# Resolve from the numbers that went on the wire, before playback starts.
	var predicted: PoolShot = match_node.get_node("Simulation").resolve_serialized(
		params_wire, rack_wire)
	_in_flight[seq] = {
		"params": params_wire,
		"hash": predicted.get_hash(),
		"rack": _confirmed_rack.duplicate_rack(),
		"state": _confirmed_state.duplicate(),
		"place": place.duplicate(true),
	}
	# Display-only ruling preview. The engine's Rust judge is used when it is
	# exposed; until then the existing pure GDScript judge runs on a duplicate
	# state. The preview never mutates the live state and COMMIT always wins.
	var sim: PoolSimulation = match_node.get_node("Simulation")
	var preview := RulingPreview.preview_from_shot(sim, predicted, params_wire,
		_confirmed_rack.duplicate_rack(), _confirmed_state.duplicate())
	if preview.foul_reason != "":
		_set_status("preview: " + preview.foul_reason)
	_current_seq = seq
	_playing = true
	_reconciled = true
	session.call("send_shot", seq, params_wire, place if not place.is_empty() else null)
	# MatchFlow replays the same post-serialization values: it uses its
	# `use_serialized_resolve` seam, so the path and hash agree with prediction.
	match_node.take_shot(_params_from_dict(params_wire))


func _on_shot_resolved(log: ShotLog) -> void:
	if not _in_flight.has(_current_seq):
		return
	var predicted := String(_in_flight[_current_seq]["hash"])
	_reconciled = predicted == log.hash
	if not _reconciled:
		# Presentation only: the authoritative rack is applied on COMMIT.
		_set_status("local hash differs from prediction; snapping on COMMIT")


func _on_local_place(position: Vector3) -> void:
	_pending_place = _place_to_wire(position)


func _on_local_aim_changed() -> void:
	if _aim_clock < AIM_INTERVAL:
		return
	_aim_clock = 0.0
	var shooter = match_node.get_node("Shooter1" if seat == 0 else "Shooter2")
	var state := AimStateReader.read(shooter)
	session.call("send_aim", {
		"level_aim_deg": state.level_aim_deg,
		"elevation_deg": state.elevation_deg,
		"english_x": state.english.x,
		"english_y": state.english.y,
		"pull_m": state.pull_m,
		"speed_m_s": state.speed_m_s,
	})
	if match_node.get_phase() == "BallInHand":
		var cue_index := _confirmed_rack.numbers.find(0)
		if cue_index >= 0:
			session.call("send_place_preview",
				{"place": _place_to_wire(_confirmed_rack.get_position(cue_index))})


# --------------------------------------------------------------- server push

func _on_room_state(message: Dictionary) -> void:
	if _playing:
		# A newer state cannot replace the rack the current shot is replaying
		# from; the COMMIT for this shot carries the same snapshot.
		return
	var rack_data: Dictionary = message.get("rack", {})
	var match_data: Dictionary = message.get("match", {})
	if rack_data.is_empty() or match_data.is_empty():
		return
	_apply_snapshot(match_data, rack_data, int(message.get("seq", -1)))
	_remaining_time = float(message.get("remaining_time", 0.0))
	_pending_place = {}
	_activate( _confirmed_state.player)


func _on_commit(message: Dictionary) -> void:
	var seq := int(message.get("seq", -1))
	if seq <= _confirmed_seq and not _in_flight.has(seq):
		return  # stale or duplicate after a resync
	# Our own shot is already replaying: attach the authoritative result to it
	# instead of queueing it, so Judging can apply it when the path ends.
	if seq >= 0 and seq == _current_seq:
		_active_commit = message
		# If the replay already ended, Judging fired once and is waiting. Apply
		# now; otherwise _on_judgement_pending will apply it at the end.
		if _judging_pending and _playing:
			_apply_authoritative(message)
		return
	_commits.push(message)
	_commits.drop_stale(_confirmed_seq)
	_try_start_next()


func _try_start_next() -> void:
	if _playing:
		return
	var message := _commits.peek()
	if message.is_empty():
		return
	var seq := int(message.get("seq", -1))
	if seq != _confirmed_seq + 1:
		return  # wait for the missing shot in sequence order
	_commits.pop()
	_active_commit = message
	_playing = true
	_current_seq = seq
	if not _in_flight.has(seq):
		# Opponent shot: replay from the last confirmed rack with the echoed,
		# validated params. Both seats therefore run one identical pipeline.
		var params := _params_from_dict(_wire(message.get("params", {})))
		match_node.take_shot(params)


func _on_judgement_pending() -> void:
	_judging_pending = true
	if _active_commit.is_empty():
		_set_status("playback finished; awaiting the authoritative COMMIT")
		return
	_apply_authoritative(_active_commit)


func _apply_authoritative(message: Dictionary) -> void:
	var seq := int(message.get("seq", -1))
	if _in_flight.has(seq):
		_reconciled = String(_in_flight[seq]["hash"]) == String(message.get("hash", ""))
		_in_flight.erase(seq)
	# COMMIT always wins: fold the validated server snapshot into the live
	# resources the existing views already read.
	var rack_data: Dictionary = message.get("rack", {})
	var match_data: Dictionary = message.get("match", {})
	if not rack_data.is_empty() and not match_data.is_empty():
		_apply_snapshot(match_data, rack_data, seq)
	var ruling := _judgement_from_dict(message.get("judgement", {}))
	# Display-only ruling preview for the HUD; no local rule is applied.
	var flow: MatchFlow = match_node.get_node("MatchFlow")
	flow.judgement_made.emit(ruling)
	if not _reconciled:
		_set_status("hash mismatch: snapped to the server rack")
	_active_commit = {}
	_playing = false
	_judging_pending = false
	_current_seq = -1
	_remaining_time = float(message.get("remaining_time", _remaining_time))
	_pending_place = {}
	if ruling.game_over:
		flow.go_to("GameOver")
		_winner = ruling.winner
		match_node.match_finished.emit(_winner)
		finished.emit(_winner)
	elif ruling.ball_in_hand:
		flow.go_to("BallInHand")
	else:
		_activate(match_node.state.player)
	_hold_remote_aim()
	_try_start_next()


func _on_error(code: String, message: String, seq: int) -> void:
	# ERROR rollback: no animated ball survives a rejected shot, and the last
	# confirmed rack and match are restored verbatim.
	match_node.get_node("ShotPlayback").cancel()
	if not _last_rack_wire.is_empty() and not _last_match_wire.is_empty():
		_apply_snapshot(_last_match_wire, _last_rack_wire, _confirmed_seq)
	_commits.clear()
	_in_flight.clear()
	_active_commit = {}
	_playing = false
	_judging_pending = false
	_current_seq = -1
	_reconciled = true
	_error_message = code + ": " + message
	_set_status("rejected " + code + " (seq " + str(seq) + ") - rack restored")
	_activate(match_node.state.player)


func _on_game_over(message: Dictionary) -> void:
	_winner = int(message.get("winner", 0))
	match_node.get_node("MatchFlow").go_to("GameOver")
	match_node.match_finished.emit(_winner)
	finished.emit(_winner)
	_set_status("game over: player " + str(_winner) + " (" +
		String(message.get("reason", "")) + ")")


func _on_match_finished(winner: int) -> void:
	_winner = winner


func _on_disconnected() -> void:
	_set_status("disconnected; reconnect with the last seen seq")


# ------------------------------------------------------------ aim / presence

func _on_aim(message: Dictionary) -> void:
	_latest_aim = message.duplicate(true)
	_hold_remote_aim()


func _on_place_preview(message: Dictionary) -> void:
	_latest_place = message.duplicate(true)
	_hold_remote_aim()


func _hold_remote_aim() -> void:
	# Updates received mid-shot are held until playback ends; then only the
	# latest value is applied, with no extrapolation.
	if _playing:
		return
	var proxy := _remote_proxy()
	if proxy == null:
		return
	if not _latest_aim.is_empty():
		var state := AimViewState.new()
		state.level_aim_deg = float(_latest_aim.get("level_aim_deg", 90.0))
		state.elevation_deg = float(_latest_aim.get("elevation_deg", 0.0))
		state.english = Vector2(float(_latest_aim.get("english_x", 0.0)),
			float(_latest_aim.get("english_y", 0.0)))
		state.pull_m = float(_latest_aim.get("pull_m", 0.0))
		state.speed_m_s = float(_latest_aim.get("speed_m_s", 0.0))
		proxy.apply_remote(state)
	if not _latest_place.is_empty():
		proxy.apply_place_preview(_latest_place.get("place", {}))


func _remote_proxy() -> RemoteAimProxy:
	if match_node == null:
		return null
	var shooter = match_node.get_node("Shooter2" if seat == 0 else "Shooter1")
	if shooter == null:
		return null
	if shooter.has_method("get_aim_proxy"):
		return shooter.call("get_aim_proxy")
	return shooter.get("aim_proxy") as RemoteAimProxy


func _on_player_activated(_player: int) -> void:
	_follow_active_view()


func _follow_active_view() -> void:
	# Match follows the HumanShooter by player number; online, the active
	# player may be the remote seat, so point the view at the right source.
	var player := match_node.get_current_player()
	var shooter = match_node.get_node(
		"Shooter1" if player == 1 else "Shooter2")
	match_node.get_node("AimView").follow(shooter)


# ------------------------------------------------------------------- helpers

func _activate(player: int) -> void:
	match_node.get_node("TurnFlow").activate(clampi(player, 1, 2))
	_follow_active_view()


func _apply_snapshot(match_data: Dictionary, rack_data: Dictionary, seq: int) -> void:
	_last_match_wire = match_data.duplicate(true)
	_last_rack_wire = rack_data.duplicate(true)
	_confirmed_seq = seq
	_confirmed_rack = _rack_from_dict(rack_data)
	_confirmed_state = _match_from_dict(match_data)
	match_node.rack.positions = _confirmed_rack.positions.duplicate()
	match_node.rack.numbers = PackedInt32Array(_confirmed_rack.numbers)
	match_node.rack.rotations = _confirmed_rack.rotations.duplicate()
	_copy_state(_confirmed_state, match_node.state)
	BallRackView.apply_state(match_node.get_node("BallRack"), match_node.rack)


func _copy_state(from_state: MatchState, to_state: MatchState) -> void:
	to_state.player = from_state.player
	to_state.solids_player = from_state.solids_player
	to_state.remaining = PackedInt32Array(from_state.remaining)
	to_state.ball_in_hand = from_state.ball_in_hand
	to_state.break_next = from_state.break_next


func _wire(value: Variant) -> Dictionary:
	# Prediction runs on post-serialization values, never on live locals.
	var parsed: Variant = JSON.parse_string(value)
	return parsed if parsed is Dictionary else {}


func _params_from_dict(data: Dictionary) -> ShotParams:
	var params := ShotParams.new()
	params.speed = float(data.get("speed", 8.0))
	params.level_aim_deg = float(data.get("level_aim_deg", 90.0))
	params.elevation_deg = float(data.get("elevation_deg", 0.0))
	params.contact_x = float(data.get("contact_x", 0.0))
	params.contact_y = float(data.get("contact_y", 0.0))
	params.called_pocket = int(data.get("called_pocket", -1))
	return params


func _rack_from_dict(data: Dictionary) -> RackState:
	var rack := RackState.new()
	rack.positions = _floats(data.get("positions", []))
	rack.numbers = _ints(data.get("numbers", []))
	rack.rotations = _floats(data.get("rotations", []))
	return rack


func _match_from_dict(data: Dictionary) -> MatchState:
	var state := MatchState.new()
	state.player = clampi(int(data.get("player", 1)), 1, 2)
	state.solids_player = clampi(int(data.get("solids_player", 0)), 0, 2)
	state.remaining = _ints(data.get("remaining", []))
	state.ball_in_hand = bool(data.get("ball_in_hand", false))
	state.break_next = bool(data.get("break_next", false))
	return state


func _judgement_from_dict(data: Dictionary) -> Judgement:
	var ruling := Judgement.new()
	ruling.foul_reason = String(data.get("foul_reason", ""))
	ruling.next_player = clampi(int(data.get("next_player",
		data.get("player", 1))), 1, 2)
	ruling.ball_in_hand = bool(data.get("ball_in_hand", false))
	ruling.re_rack = bool(data.get("re_rack", false))
	ruling.solids_player = clampi(int(data.get("solids_player", 0)), 0, 2)
	ruling.game_over = bool(data.get("game_over", false))
	ruling.winner = clampi(int(data.get("winner", 0)), 0, 2)
	return ruling


func _place_to_wire(display: Vector3) -> Dictionary:
	# Core frame: core (x, y, z) = display (x, -z, y); cue z is implied.
	return {"x": display.x, "y": -display.z}


static func _floats(value: Variant) -> Array[float]:
	var out: Array[float] = []
	for item in value:
		out.append(float(item))
	return out


static func _ints(value: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	for item in value:
		out.append(int(item))
	return out


func _set_status(text: String) -> void:
	_error_message = text if text.begins_with("rejected") else _error_message
	var label := get_node_or_null("OnlineStatus/Status")
	if label != null:
		label.text = text


func _refresh_status() -> void:
	var peer := get_node_or_null("OnlineStatus/Peer")
	if peer != null:
		peer.text = "peer: " + (peer_name if peer_name != "" else "seat " + str((seat + 1) % 2 + 1))
	var rtt := get_node_or_null("OnlineStatus/Rtt")
	if rtt != null and session != null:
		rtt.text = "RTT: " + str(int(session.get("rtt_ms"))) + " ms"
	var clock := get_node_or_null("OnlineStatus/Clock")
	if clock != null:
		clock.text = "time: " + str(int(maxf(0.0, _remaining_time))) + " s"
	var reconcile := get_node_or_null("OnlineStatus/Reconcile")
	if reconcile != null:
		reconcile.text = ("hash: agreed" if _reconciled else "hash: snapped") + (
			" | " + _error_message if _error_message != "" else "")
