# lint-ignore-file: cli-in-game-script (dev-only screenshot harness, never in the game)
extends Node

## Dev-only screenshot harness. Run on X11 at a fixed window size:
## godot --path . --display-driver x11 --rendering-driver opengl3 --windowed \
##   --resolution 1920x1080 res://tools/ui_capture.tscn -- --screen=title --out=/abs/title.png

const MENU := "res://scenes/main_menu/main_menu.tscn"
const HUD := "res://scenes/hud/hud.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var screen := _arg(args, "screen", "title")
	var out := _arg(args, "out", "user://capture.png")
	if not args.has("--fullscreen") and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var menu := (load(MENU) as PackedScene).instantiate()
	add_child(menu)
	var splash := menu.get_node_or_null("BootSplash") as BootSplash
	if splash != null:
		splash.hide_splash()
	if screen == "options":
		menu.show_options()
	elif screen == "match" or screen == "pause":
		menu.hide()
		$FeltBackdrop.show()
		var hud := (load(HUD) as PackedScene).instantiate()
		add_child(hud)
		hud.show_state(_state())
		if screen == "pause":
			hud.toggle_pause()

	for i in range(8):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var target := DisplayServer.window_get_size()
	if image.get_size() != target:
		image.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
	var err := image.save_png(out)
	if err != OK:
		push_error("ui-capture: save failed (%d)" % err)
		get_tree().quit(1)
		return
	print("ui-capture: %s %s -> %s" % [screen, target, out])
	get_tree().quit(0)


func _state() -> MatchState:
	var state := MatchState.new()
	state.player = 2
	state.solids_player = 1
	state.remaining = PackedInt32Array([1, 4, 6, 8, 9, 13, 15])
	return state


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	for arg in args:
		if arg.begins_with("--%s=" % key):
			return String(arg.split("=")[1])
	return fallback
