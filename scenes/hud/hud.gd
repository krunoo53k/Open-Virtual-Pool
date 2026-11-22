class_name Hud
extends CanvasLayer

## Display-only match HUD: it shows the MatchState and Judgement it is handed,
## reacts to the rules node's foul signal, and forwards the player's intents as
## signals. It owns no rules, keeps no match state and reaches no other tree.

signal pocket_called(index: int)
signal resume_requested()
signal restart_requested()
signal menu_requested()

@onready var _turn_status: TurnStatus = $TurnStatus
@onready var _foul_banner: FoulBanner = $FoulBanner
@onready var _result_banner: ResultBanner = $ResultBanner
@onready var _picker: CalledPocketPicker = $CalledPocketPicker
@onready var _pause: PauseMenu = $PauseMenu

func show_state(state: MatchState) -> void:
	_turn_status.show_state(state)
	_picker.visible = _shoots_for_eight(state)


func show_judgement(ruling: Judgement) -> void:
	_result_banner.show_result(ruling.winner if ruling.game_over else 0)
	if ruling.foul_reason == "":
		_foul_banner.show_reason("")


func on_foul_committed(reason: String) -> void:
	_foul_banner.show_reason(reason)


func set_called_pocket(index: int) -> void:
	_picker.set_selection(index)


func toggle_pause() -> void:
	_pause.set_open(not _pause.is_open())


func is_pause_open() -> bool:
	return _pause.is_open()


func _on_pocket_called(index: int) -> void:
	pocket_called.emit(index)


func _on_resume_requested() -> void:
	resume_requested.emit()


func _on_restart_requested() -> void:
	restart_requested.emit()


func _on_menu_requested() -> void:
	menu_requested.emit()


func _shoots_for_eight(state: MatchState) -> bool:
	# Display only: show the call picker when the shooter's group is gone and
	# the 8 is still on the table. The rules node still decides the call.
	if state.solids_player == 0 or not state.remaining.has(8):
		return false
	for n in state.remaining:
		if n != 8 and (n <= 7) == (state.solids_player == state.player):
			return false
	return true
