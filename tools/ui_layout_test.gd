# lint-ignore-file: cli-in-game-script (dev-only layout harness, never in the game)
extends Node

## Headless layout acceptance: run once per resolution with
## godot --headless --path . res://tools/ui_layout_test.tscn -- --width=1366 --height=768
## It checks the real menu and HUD for clipping and off-screen controls,
## then checks the custom theme and the potted-ball indicator.

const MENU := "res://scenes/main_menu/main_menu.tscn"
const HUD := "res://scenes/hud/hud.tscn"
const VIEW := Vector2(1920, 1080)

var _fails := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var wanted := Vector2i(_arg(args, "width", 1920), _arg(args, "height", 1080))
	DisplayServer.window_set_size(wanted)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_size() != wanted:
		_fail("window size %s != %s" % [DisplayServer.window_get_size(), wanted])
	var logical := get_viewport().get_visible_rect().size
	if logical != VIEW:
		_fail("logical viewport %s != %s" % [logical, VIEW])

	var menu := (load(MENU) as PackedScene).instantiate()
	add_child(menu)
	var hud := (load(HUD) as PackedScene).instantiate()
	add_child(hud)
	var state := MatchState.new()
	state.remaining = PackedInt32Array([1, 2, 4, 5, 8, 9, 10, 12, 14])
	hud.show_state(state)
	await get_tree().process_frame
	await get_tree().process_frame

	for path in ["Backdrop", "TitleButtons/Menu", "TitleButtons/Menu/Title",
		"TitleButtons/Menu/PlayButton", "OptionsPanel/Panel", "BootSplash"]:
		_bounds(menu, path)
	for path in ["TurnStatus", "BallTracker", "FoulBanner", "ResultBanner",
		"CalledPocketPicker", "PauseMenu"]:
		_bounds(hud, path)
	if hud.get_node_or_null("VersionStamp") == null:
		_fail("version stamp missing")
	_balls(hud, state)
	_fonts(menu)
	print("ui-layout %dx%d: %d failures" % [wanted.x, wanted.y, _fails])
	get_tree().quit(_fails)


func _arg(args: PackedStringArray, key: String, fallback: int) -> int:
	for arg in args:
		if arg.begins_with("--%s=" % key):
			return int(arg.split("=")[1])
	return fallback


func _bounds(host: Node, path: String) -> void:
	var control := host.get_node_or_null(path) as Control
	if control == null:
		_fail("missing control: " + path)
		return
	if not control.visible:
		return
	var rect := control.get_global_rect()
	if rect.position.x < -1 or rect.position.y < -1 or rect.end.x > VIEW.x + 1 or rect.end.y > VIEW.y + 1:
		_fail("off-screen: %s %s" % [path, rect])
	var minimum := control.get_combined_minimum_size()
	if control.size.x + 1 < minimum.x or control.size.y + 1 < minimum.y:
		_fail("clipped: %s size %s min %s" % [path, control.size, minimum])


func _balls(hud: Node, state: MatchState) -> void:
	var tracker := hud.get_node_or_null("BallTracker") as BallTracker
	if tracker == null:
		_fail("ball tracker missing")
		return
	for n in range(1, 16):
		var want := not state.remaining.has(n)
		if tracker.is_potted(n) != want:
			_fail("ball %d potted state wrong" % n)
		var token := tracker.get_node_or_null(_row(n)) as BallToken
		if token == null or token.texture == null or token.size.x < 1:
			_fail("ball %d token not rendered" % n)


func _row(n: int) -> String:
	if n <= 7:
		return "Margin/VBox/SolidsRow/Ball%d" % n
	if n == 8:
		return "Margin/VBox/EightRow/Ball8"
	return "Margin/VBox/StripesRow/Ball%d" % n


func _fonts(menu: Node) -> void:
	var button := menu.get_node("TitleButtons/Menu/PlayButton") as Button
	var font: Font = button.get_theme_font("font")
	if not (font is FontFile) or not String(font.resource_path).ends_with("SemiBold.ttf"):
		_fail("custom button font not applied")
	var title := menu.get_node("TitleButtons/Menu/Title") as Label
	if title.get_theme_font_size("font_size") != 68:
		_fail("title font size not applied")


func _fail(message: String) -> void:
	_fails += 1
	printerr("ui-layout said no: ", message)
