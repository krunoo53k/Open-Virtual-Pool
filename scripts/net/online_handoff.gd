class_name OnlineHandoff
extends RefCounted

## Carries the live session and seat across `change_scene_to_file`, which frees
## the lobby. GDScript static variables are the only hand-off available without
## an autoload; take_handoff() clears them so a stale match cannot be re-entered.

static var session: NetworkSession = null
static var seat: int = -1
static var room_id: String = ""
static var peer_name: String = ""


static func set_handoff(new_session: NetworkSession, new_seat: int,
		new_room_id: String, new_peer_name: String) -> void:
	session = new_session
	seat = new_seat
	room_id = new_room_id
	peer_name = new_peer_name


static func take_handoff() -> Dictionary:
	var carried := {
		"session": session,
		"seat": seat,
		"room_id": room_id,
		"peer_name": peer_name,
	}
	session = null
	seat = -1
	room_id = ""
	peer_name = ""
	return carried
