extends Node

## Headless acceptance for the centred result panel and its menu intent.

var _fails := 0


func _ready() -> void:
	var hud := (load("res://scenes/hud/hud.tscn") as PackedScene).instantiate()
	add_child(hud)
	var intents: Array[String] = []
	hud.menu_requested.connect(func(): intents.append("menu"))

	var ruling := Judgement.new()
	ruling.game_over = true
	ruling.winner = 1
	hud.show_judgement(ruling)
	var banner := hud.get_node("ResultBanner") as ResultBanner
	var backdrop := hud.get_node("ResultBackdrop") as ColorRect
	_check(banner.visible and banner.result_text() == "player 1 wins!", "winner shown")
	_check(backdrop.visible, "backdrop shown at game over")
	(hud.get_node("ResultBanner/Margin/VBox/BackToMenu") as Button).pressed.emit()
	_check(intents == ["menu"], "menu intent forwarded")

	ruling.game_over = false
	ruling.winner = 0
	hud.show_judgement(ruling)
	_check(not banner.visible and not backdrop.visible, "hidden on a non-final ruling")
	print("result banner: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _check(ok: bool, note: String) -> void:
	if not ok:
		_fails += 1
		printerr("result banner said no: ", note)
