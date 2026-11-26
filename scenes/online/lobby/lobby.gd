class_name Lobby
extends Control

## Themed lobby: connection fields, room list and clear rejection messages.
## It owns a NetworkSession and hands it (plus the seat) to the online match
## scene through OnlineHandoff. No physics and no rules live here.

const ONLINE_MATCH_SCENE := "res://scenes/online/online_match/online_match.tscn"
const TITLE_SCENE := "res://scenes/main_menu/main_menu.tscn"

@onready var _server_url: LineEdit = $Panel/Margin/VBox/ServerRow/ServerUrl
@onready var _player_name: LineEdit = $Panel/Margin/VBox/NameRow/PlayerName
@onready var _connect: Button = $Panel/Margin/VBox/ConnectButton
@onready var _disconnect: Button = $Panel/Margin/VBox/DisconnectButton
@onready var _rooms: ItemList = $Panel/Margin/VBox/RoomList
@onready var _status: Label = $Panel/Margin/VBox/Status

var _session: NetworkSession
var _room_ids: Array[String] = []


func _ready() -> void:
	var settings: Dictionary = OnlineSettings.load_settings()
	_server_url.text = str(settings["server_url"])
	_player_name.text = str(settings["player_name"])
	_session = NetworkSession.new()
	add_child(_session)
	_session.player_name = _player_name.text
	_session.connected_to_server.connect(_on_connected)
	_session.welcome.connect(_on_welcome)
	_session.room_list.connect(_on_room_list)
	_session.room_state.connect(_on_room_state)
	_session.match_start_received.connect(_on_match_start)
	_session.error_received.connect(_on_error)
	_session.disconnected.connect(_on_disconnected)
	_session.game_over.connect(_on_game_over)
	$Panel/Margin/VBox/ConnectButton.pressed.connect(_on_connect_pressed)
	$Panel/Margin/VBox/DisconnectButton.pressed.connect(_on_disconnect_pressed)
	$Panel/Margin/VBox/RoomActions/CreateRoomButton.pressed.connect(_on_create_pressed)
	$Panel/Margin/VBox/RoomActions/JoinSelectedButton.pressed.connect(_on_join_pressed)
	$Panel/Margin/VBox/BackButton.pressed.connect(_on_back_pressed)
	_disconnect.disabled = true
	_status.text = "Enter a server URL and name, then Connect."


func _on_connect_pressed() -> void:
	var name := _player_name.text.strip_edges()
	if name.length() < 1 or name.length() > 24:
		_status.text = "Player name must be 1-24 characters."
		return
	OnlineSettings.save_settings(_server_url.text.strip_edges(), name)
	_session.player_name = name
	_status.text = "Connecting to " + _server_url.text.strip_edges() + " ..."
	_session.connect_to_server(_server_url.text.strip_edges())


func _on_disconnect_pressed() -> void:
	_session.disconnect_from_server()


func _on_connected() -> void:
	_disconnect.disabled = false
	_status.text = "Connected. Create a room or join one below."


func _on_welcome(_token: String) -> void:
	_status.text = "Session established with the server."


func _on_room_list(rooms: Array) -> void:
	_rooms.clear()
	_room_ids.clear()
	for room in rooms:
		var label := str(room)
		var id := str(room)
		if typeof(room) == TYPE_DICTIONARY:
			label = str(room.get("name", room.get("id", "")))
			id = str(room.get("id", label))
		_rooms.add_item(label)
		_room_ids.append(id)


func _on_create_pressed() -> void:
	if not _session.is_socket_connected():
		_status.text = "Connect to a server before creating a room."
		return
	_session.send_room_create(_player_name.text.strip_edges())
	_status.text = "Create-room request sent."


func _on_join_pressed() -> void:
	var selected: int = _rooms.get_selected(0)
	if selected < 0 or selected >= _room_ids.size():
		_status.text = "Select a room first."
		return
	_session.send_room_join(_room_ids[selected])
	_status.text = "Join-room request sent for " + _room_ids[selected] + "."


func _on_room_state(state: Dictionary) -> void:
	var seat_index := int(state.get("seat", _session.seat))
	_status.text = "Room %s — seat %d (%s)" % [
		str(state.get("room", _session.room_id)), seat_index,
		"player 1" if seat_index == 0 else "player 2",
	]


func _on_match_start(data: Dictionary) -> void:
	var seat_index := int(data.get("seat", _session.seat))
	if seat_index != 0 and seat_index != 1:
		seat_index = 0
	OnlineHandoff.set_handoff(_session, seat_index,
		str(data.get("room", _session.room_id)),
		str(data.get("peer_name", _session.peer_name)))
	if not ResourceLoader.exists(ONLINE_MATCH_SCENE):
		_status.text = "Match starting, but " + ONLINE_MATCH_SCENE + " is not available yet."
		return
	# The session is reparented to the root so the scene change does not free it.
	get_tree().root.add_child(_session)
	_status.text = "Starting online match as player %d ..." % (seat_index + 1)
	get_tree().change_scene_to_file(ONLINE_MATCH_SCENE)


func _on_error(code: String, message: String, _seq: int) -> void:
	if code == "version_mismatch" or code == "canary_mismatch":
		_status.text = "REJECTED (%s): %s — no room was joined." % [code, message]
	else:
		_status.text = "Error %s: %s" % [code, message]


func _on_game_over(data: Dictionary) -> void:
	_status.text = "Game over: winner %s, reason %s" % [
		str(data.get("winner", 0)), str(data.get("reason", "")),
	]


func _on_disconnected() -> void:
	_disconnect.disabled = true
	_status.text = "Disconnected from the server."


func _on_back_pressed() -> void:
	if ResourceLoader.exists(TITLE_SCENE):
		get_tree().change_scene_to_file(TITLE_SCENE)
