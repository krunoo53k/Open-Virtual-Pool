class_name NetworkSession
extends Node

## One WebSocket connection to an authoritative server. Owns no physics and no
## rules: it serializes, validates, dispatches and keeps the last confirmed
## snapshot. Every signal payload handing a snapshot to the core has first been
## through SnapshotValidator.
##
## ENGINE NOTE: this Godot 4.7.2 build exposes `WebSocketPeer` (a polling
## client/server peer) and does not expose a `WebSocketClient` class. The
## lifecycle below is the WebSocketClient lifecycle expressed with that peer:
## connect_to_url -> poll until STATE_OPEN -> send HELLO -> poll packets ->
## PING/PONG heartbeat -> close. No autoload, no SceneTree hooks.

signal connected_to_server
signal welcome(token: String)
signal room_list(rooms: Array)
signal room_state(state: Dictionary)
signal commit(data: Dictionary)
signal aim_received(data: Dictionary)
signal place_preview_received(data: Dictionary)
signal game_over(data: Dictionary)
signal error_received(code: String, message: String, seq: int)
signal disconnected
signal state_received(data: Dictionary)
signal pong(rtt_ms: int)

## Extra hooks used by the lobby (the catalogue's MATCH_START is not otherwise
## represented above).
signal match_start_received(data: Dictionary)

const HELLO_TIMEOUT_MS := 5000
const PING_INTERVAL_MS := 5000
const PONG_TIMEOUT_MS := 10000
const AIM_MIN_INTERVAL_MS := 66
const MAX_FRAME_BYTES := 64 * 1024

var token := ""
var rtt_ms := -1
var peer_name := ""
var room_id := ""
var seat := -1

## Last authoritative wire snapshot, kept as the PARSED dictionaries so a
## prediction can run on exactly the numbers that crossed the socket.
var last_seen_seq := -1
var last_confirmed_rack: Dictionary = {}
var last_confirmed_match: Dictionary = {}
var in_flight_seq := -1

var player_name := "Player"

## Untyped so a harness can inject a socket double (see tools/network_ping_test).
## Production always assigns a WebSocketPeer.
var _peer = null
var _layout = null
var _active := false
var _hello_sent := false
var _connect_ms := 0
var _last_ping_ms := 0
var _last_pong_ms := 0
var _ping_sent_ms := 0
var _pending_aim: Dictionary = {}
var _pending_place: Dictionary = {}
var _last_aim_ms := 0
var _last_place_ms := 0


func _ready() -> void:
	if ClassDB.class_exists("PoolCore"):
		var core = PoolCore.new()
		if core.has_method("get_table_geometry"):
			_layout = TableLayout.build(core.get_table_geometry())


## Validate the URL and start connecting. The HELLO is sent the instant the
## socket opens, well inside the protocol's 5-second deadline.
func connect_to_server(url: String) -> void:
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		error_received.emit("malformed", "server URL must start with ws:// or wss://", -1)
		return
	if _peer != null:
		disconnect_from_server()
	_peer = WebSocketPeer.new()
	# One argument keeps ws:// plain and lets Godot supply default TLS options
	# for wss:// (certificate validation on). No custom headers are needed.
	var err: int = _peer.connect_to_url(url)
	if err != OK:
		push_warning("NetworkSession: connect_to_url failed: %s" % err)
		_peer = null
		error_received.emit("malformed", "could not start the WebSocket connection", -1)
		return
	_active = true
	_hello_sent = false
	_connect_ms = Time.get_ticks_msec()
	_last_ping_ms = _connect_ms
	_last_pong_ms = _connect_ms
	rtt_ms = -1


## Alias for callers that prefer the protocol doc's spelling.
func open(url: String) -> void:
	connect_to_server(url)


func disconnect_from_server() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	if _active:
		_active = false
		disconnected.emit()


## Renamed from `is_connected` because Object already owns that method.
func is_socket_connected() -> bool:
	return _peer != null and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN


func _process(_delta: float) -> void:
	if _peer == null:
		return
	var previous: int = _peer.get_ready_state()
	_peer.poll()
	var state: int = _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and previous != WebSocketPeer.STATE_OPEN:
		_on_open()
	elif state == WebSocketPeer.STATE_CLOSED and previous != WebSocketPeer.STATE_CLOSED:
		_on_close()
	while state == WebSocketPeer.STATE_OPEN and _peer.get_available_packet_count() > 0:
		var packet: PackedByteArray = _peer.get_packet()
		if _peer.was_string_packet():
			_on_data(packet.get_string_from_utf8())
	if not _active:
		return
	var now := Time.get_ticks_msec()
	if not _hello_sent and now - _connect_ms > HELLO_TIMEOUT_MS:
		_fail("malformed", "connection timed out before HELLO", -1)
		return
	if _hello_sent:
		if now - _last_pong_ms > PONG_TIMEOUT_MS:
			_fail("malformed", "heartbeat timed out: no PONG in 10 s", -1)
			return
		if now - _last_ping_ms >= PING_INTERVAL_MS:
			_last_ping_ms = now
			_ping_sent_ms = now
			send({"type": "PING"})
	_flush_coalesced(now)


func _on_open() -> void:
	var core = null
	if ClassDB.class_exists("PoolCore"):
		core = PoolCore.new()
	var canary := DeterminismCanary.compute(core)
	_hello_sent = true
	_last_ping_ms = Time.get_ticks_msec()
	_last_pong_ms = _last_ping_ms
	connected_to_server.emit()
	send(ProtocolVersions.hello_fields(core, player_name, canary))


func _on_close() -> void:
	if not _active:
		return
	_active = false
	_peer = null
	disconnected.emit()


func _fail(code: String, message: String, seq: int) -> void:
	error_received.emit(code, message, seq)
	disconnect_from_server()


## Full-precision JSON and the 64 KiB cap. Returns false without throwing when
## the socket is down or the frame is too large.
func send(message: Dictionary) -> bool:
	var text := ProtocolCodec.stringify(message)
	if text.to_utf8_buffer().size() > MAX_FRAME_BYTES:
		error_received.emit("malformed", "outbound frame exceeds 64 KiB", int(message.get("seq", -1)))
		return false
	if not is_socket_connected():
		return false
	var err: int = _peer.send_text(text)
	if err != OK:
		push_warning("NetworkSession: send_text failed: %s" % err)
		return false
	return true


func _on_data(text: String) -> void:
	var parsed: Variant = ProtocolCodec.parse(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		error_received.emit("malformed", "frame is not a JSON object", -1)
		return
	var data: Dictionary = parsed
	var type := str(data.get("type", ""))
	if type.is_empty():
		error_received.emit("malformed", "frame has no type", -1)
		return
	match type:
		"PONG":
			var now := Time.get_ticks_msec()
			if _ping_sent_ms > 0:
				rtt_ms = max(0, now - _ping_sent_ms)
				pong.emit(rtt_ms)
			_last_pong_ms = now
		"WELCOME":
			token = str(data.get("token", ""))
			welcome.emit(token)
		"ROOM_LIST":
			room_list.emit(Array(data.get("rooms", [])))
		"ROOM_STATE":
			_emit_snapshot("room_state", room_state, data)
		"STATE":
			_emit_snapshot("state_received", state_received, data)
		"COMMIT":
			_on_commit(data)
		"AIM":
			aim_received.emit(data)
		"PLACE_PREVIEW":
			place_preview_received.emit(data)
		"GAME_OVER":
			_on_game_over(data)
		"ERROR":
			_on_error(data)
		"MATCH_START":
			_remember(data)
			match_start_received.emit(data)
		"PING":
			# Protocol §2: a server heartbeat must be answered or the server
			# drops this connection after 10 s without a PONG.
			send({"type": "PONG"})
		"ROOM_CREATE", "ROOM_JOIN", "ROOM_LEFT", "PLAYER_READY", "REMATCH":
			_remember(data)
		_:
			# Unknown types are logged and ignored; never crash on a frame from
			# an arbitrary server.
			push_warning("NetworkSession: unknown message type: " + type)


func _remember(data: Dictionary) -> void:
	if data.has("room"):
		room_id = str(data["room"])
	if data.has("seat"):
		seat = int(data["seat"])
	if data.has("peer_name"):
		peer_name = str(data["peer_name"])


## Validate a snapshot before emitting it. Returns the normalised dictionary
## or an empty dictionary after emitting error_received("malformed", ...).
func _checked_snapshot(label: String, data: Dictionary) -> Dictionary:
	var rack_check := SnapshotValidator.validate_rack(data.get("rack", {}), _layout)
	if not rack_check["ok"]:
		error_received.emit("malformed", label + ": " + str(rack_check["error"]),
			int(data.get("seq", -1)))
		return {}
	var match_check := SnapshotValidator.validate_match(data.get("match", {}))
	if not match_check["ok"]:
		error_received.emit("malformed", label + ": " + str(match_check["error"]),
			int(data.get("seq", -1)))
		return {}
	var out := data.duplicate()
	out["rack"] = ProtocolCodec.rack_to_dict(rack_check["rack"])
	out["match"] = _match_to_dict(match_check["match"])
	last_confirmed_rack = out["rack"]
	last_confirmed_match = out["match"]
	if data.has("seq"):
		last_seen_seq = int(data["seq"])
	_remember(data)
	return out


func _emit_snapshot(label: String, target: Signal, data: Dictionary) -> void:
	var checked := _checked_snapshot(label, data)
	if not checked.is_empty():
		target.emit(checked)


func _on_commit(data: Dictionary) -> void:
	var check := SnapshotValidator.validate_commit(data)
	if not check["ok"]:
		error_received.emit("malformed", "commit: " + str(check["error"]),
			int(data.get("seq", -1)))
		return
	var rack_check := SnapshotValidator.validate_rack(data.get("rack", {}), _layout)
	if not rack_check["ok"]:
		error_received.emit("malformed", "commit rack: " + str(rack_check["error"]),
			int(data.get("seq", -1)))
		return
	last_confirmed_rack = ProtocolCodec.rack_to_dict(rack_check["rack"])
	last_confirmed_match = _match_to_dict(SnapshotValidator.validate_match(data.get("match", {}))["match"])
	last_seen_seq = int(data["seq"])
	in_flight_seq = -1
	_remember(data)
	commit.emit(data)


func _on_game_over(data: Dictionary) -> void:
	var reason := str(data.get("reason", ""))
	if not SnapshotValidator.is_known_game_over_reason(reason):
		error_received.emit("malformed", "unknown game over reason: " + reason, -1)
		return
	game_over.emit(data)


func _on_error(data: Dictionary) -> void:
	var code := str(data.get("code", ""))
	if not SnapshotValidator.is_known_error_code(code):
		code = "malformed"
	var seq := int(data.get("seq", -1))
	if data.has("snapshot"):
		var checked := _checked_snapshot("error snapshot", data["snapshot"])
		if checked.is_empty():
			return
	in_flight_seq = -1
	error_received.emit(code, str(data.get("message", "")), seq)


func _match_to_dict(state: MatchState) -> Dictionary:
	var remaining: Array = []
	for n in state.remaining:
		remaining.append(int(n))
	return {
		"player": state.player,
		"solids_player": state.solids_player,
		"remaining": remaining,
		"ball_in_hand": state.ball_in_hand,
		"break_next": state.break_next,
	}


# ---------------------------------------------------------------------------
# Outbound frames
# ---------------------------------------------------------------------------

func send_shot(seq: int, params_dict: Dictionary, place_or_null) -> bool:
	var message := {
		"type": "SHOT",
		"room": room_id,
		"seq": seq,
		"params": params_dict,
	}
	if place_or_null != null:
		message["place"] = place_or_null
	in_flight_seq = seq
	return send(message)


## AIM and PLACE_PREVIEW are coalesced: the latest value wins, with a ~66 ms
## floor. SHOT and COMMIT never go through this path, so they are never delayed.
func send_aim(aim_dict: Dictionary) -> void:
	var message := aim_dict.duplicate()
	message["type"] = "AIM"
	if not room_id.is_empty():
		message["room"] = room_id
	_pending_aim = message


func send_place_preview(place_dict: Dictionary) -> void:
	var message := place_dict.duplicate()
	message["type"] = "PLACE_PREVIEW"
	if not room_id.is_empty():
		message["room"] = room_id
	_pending_place = message


func _flush_coalesced(now: int) -> void:
	if not _pending_aim.is_empty() and now - _last_aim_ms >= AIM_MIN_INTERVAL_MS:
		if send(_pending_aim):
			_last_aim_ms = now
		_pending_aim.clear()
	if not _pending_place.is_empty() and now - _last_place_ms >= AIM_MIN_INTERVAL_MS:
		if send(_pending_place):
			_last_place_ms = now
		_pending_place.clear()


func send_room_create(room_name: String) -> bool:
	return send({"type": "ROOM_CREATE", "name": room_name})


func send_room_join(id: String) -> bool:
	var ok := send({"type": "ROOM_JOIN", "room": id})
	if ok:
		room_id = id
	return ok


func send_ready(ready: bool) -> bool:
	return send({"type": "PLAYER_READY", "room": room_id, "ready": ready})


func send_resync(last_seen: int) -> bool:
	return send({
		"type": "RESYNC_REQUEST",
		"room": room_id,
		"token": token,
		"last_seen_seq": last_seen,
	})


func send_leave() -> bool:
	return send({"type": "ROOM_LEFT", "room": room_id})


func send_rematch(ready: bool) -> bool:
	return send({"type": "REMATCH", "room": room_id, "ready": ready})
