extends Node
class_name FakeOnlineSession

## Harness double for NetworkSession: same signal surface, records every
## outbound message. No socket, no server, no physics.

signal room_state(message: Dictionary)
signal commit(message: Dictionary)
signal error_received(code: String, message: String, seq: int)
signal game_over(message: Dictionary)
signal aim_received(message: Dictionary)
signal place_preview_received(message: Dictionary)
signal disconnected

var rtt_ms := 12
var sent: Array[Dictionary] = []


func send_shot(seq: int, params: Dictionary, place: Variant) -> void:
	sent.append({"type": "SHOT", "seq": seq, "params": params, "place": place})


func send_aim(message: Dictionary) -> void:
	sent.append({"type": "AIM", "message": message})


func send_place_preview(message: Dictionary) -> void:
	sent.append({"type": "PLACE_PREVIEW", "message": message})


func send_leave() -> void:
	sent.append({"type": "LEAVE"})


func has_type(type: String) -> bool:
	for item in sent:
		if String(item.get("type", "")) == type:
			return true
	return false
