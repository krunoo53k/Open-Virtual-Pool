extends Node

## Protocol §2: an inbound PING must be answered with PONG. The socket is
## replaced by a deterministic double so the heartbeat can be exercised
## without a server. Exit code 0 = pass.

class FakePeer extends RefCounted:
	var packets: Array[PackedByteArray] = []
	var sent: Array[String] = []

	func poll() -> void:
		pass

	func get_ready_state() -> int:
		return WebSocketPeer.STATE_OPEN

	func get_available_packet_count() -> int:
		return packets.size()

	func get_packet() -> PackedByteArray:
		return packets.pop_front()

	func was_string_packet() -> bool:
		return true

	func send_text(text: String) -> int:
		sent.append(text)
		return OK


func _ready() -> void:
	var session := NetworkSession.new()
	add_child(session)
	var peer := FakePeer.new()
	var text := '{"type":"PING"}'
	var bytes := PackedByteArray()
	for byte in text.to_utf8_buffer():
		bytes.append(byte)
	peer.packets.append(bytes)
	session._peer = peer
	session._active = true
	session._hello_sent = false
	session._connect_ms = Time.get_ticks_msec()
	session._process(0.0)
	var answered := false
	for sent_text in peer.sent:
		var parsed: Variant = JSON.parse_string(sent_text)
		if parsed is Dictionary and str(parsed.get("type", "")) == "PONG":
			answered = true
	if answered:
		print("  PASS: inbound PING is answered with PONG")
	else:
		printerr("  FAIL: no PONG was sent (server would disconnect after 10 s)")
	print("network ping: ", 0 if answered else 1, " failures")
	get_tree().quit(0 if answered else 1)
