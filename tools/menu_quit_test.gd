extends Node
class_name MenuQuitTest

## Proves the Quit button's public path ends the process with code 0.

const MENU_SCENE := preload("res://scenes/main_menu/main_menu.tscn")


func _ready() -> void:
	var menu := MENU_SCENE.instantiate() as MainMenu
	add_child(menu)
	print("MENU QUIT PATH: calling MainMenu.quit()")
	menu.quit()
