class_name HudWiring
extends Node

## One job: route data and intents between the match composer and the Hud.
## The Hud stays a pure view; this node owns pause actions and forwards the
## pocket call. Rules and phase transitions still live in the match flow.

signal pocket_called(index: int)

const MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

var _hud: Hud
var _state: MatchState

func wire(hud_view: Hud, rules: EightBallRules, state: MatchState) -> void:
	_hud = hud_view
	_state = state
	rules.foul_committed.connect(_hud.on_foul_committed)
	_hud.pocket_called.connect(_on_pocket)
	_hud.resume_requested.connect(_on_pause_intent.bind("resume"))
	_hud.restart_requested.connect(_on_pause_intent.bind("restart"))
	_hud.menu_requested.connect(_on_pause_intent.bind("menu"))
	$CancelInput.cancel_requested.connect(_on_pause_intent.bind("toggle"))
	_hud.show_state(_state)


func on_judgement(ruling: Judgement) -> void:
	_hud.show_judgement(ruling)
	_hud.show_state(_state)


func _on_pocket(index: int) -> void:
	pocket_called.emit(index)


func _on_pause_intent(intent: String) -> void:
	if intent == "toggle":
		_hud.toggle_pause()
		get_tree().paused = _hud.is_pause_open()
		return
	get_tree().paused = false
	if intent == "resume":
		_hud.toggle_pause()
	elif intent == "restart":
		get_tree().reload_current_scene()
	elif intent == "menu" and ResourceLoader.exists(MENU_SCENE):
		get_tree().change_scene_to_file(MENU_SCENE)
