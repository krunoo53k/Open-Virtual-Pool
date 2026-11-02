
extends Node3D
class_name InputSceneTest

## Headless acceptance harness for issue #4: drives the input scene tree
## with real key and mouse events, exactly as the playground ran them,
## and checks every gesture's contract at the scene's own level. The
## exit code is the number of contracts that said no.

const SHOOTER_SCENE := preload("res://scenes/input/human_shooter/human_shooter.tscn")
const SIM_SCENE := preload("res://scenes/pool_simulation.tscn")

const TINY := 0.000000000001

var _fails: Array[String] = []
var _cue: Node3D
var _aim_leaf: AimInput = null
var _stroke_leaf: StrokeInput = null
var _english_leaf: EnglishInput = null
var _elevation_leaf: ElevationInput = null
var _shot: ShotParams = null

func _ready() -> void:
	var sim := SIM_SCENE.instantiate()
	add_child(sim)
	var cue: HumanShooter = SHOOTER_SCENE.instantiate()
	cue.core = sim
	add_child(cue)
	_cue = cue
	_aim_leaf = cue.get_aim_leaf()
	_stroke_leaf = cue.get_stroke_leaf()
	_english_leaf = cue.get_english_leaf()
	_elevation_leaf = cue.get_elevation_leaf()
	cue.shot_prepared.connect(_capture_shot)
	await _the_turn_turns_the_line()
	await _the_fine_trim_holds_the_same_turn_back()
	await _the_aim_never_drifts_once_settled()
	await _the_english_moves_the_tip_and_not_the_shot()
	await _the_tip_stays_inside_the_miscue_disc()
	await _a_new_press_resets_the_tip_to_centre()
	await _the_draw_starts_on_the_key_and_runs_on_the_mouse()
	await _the_aim_is_left_alone_while_the_cue_is_drawn()
	await _the_release_cancels_and_forgets_the_stroke()
	await _the_flick_that_came_back_home_is_a_stroke()
	await _the_aim_after_the_stroke_never_wobbles()
	await _the_escape_cancels_a_charging_stroke()
	await _the_raise_lifts_the_butt_not_the_line()
	await _the_raise_and_home_make_a_jump_shot()
	await _the_next_stroke_after_the_settle_fires_again()
	if _fails.is_empty():
		print("HUMAN SHOOTER OK: the turn, trim, english, draw, cancel, raise and every shot contract hold")
	else:
		for f in _fails:
			printerr("input scene said no: ", f)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fails.is_empty() else 1)

func _capture_shot(params: ShotParams) -> void:
	_shot = params

func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)

func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _press_key(action_name: String, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)

func _release_key(action_name: String, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)

func _mouse(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	Input.parse_input_event(event)
	await _frames(2)

func _turn_expected(px: float, tune: CueTuning) -> float:
	return rad_to_deg(-px * tune.look_speed_rad_per_px)

func _the_turn_turns_the_line() -> void:
	var before := _aim_leaf.get_level_aim_deg()
	await _mouse(Vector2(40.0, 0.0))
	var expected := before + _turn_expected(40.0, _aim_leaf.tuning)
	_check(abs(_aim_leaf.get_level_aim_deg() - expected) < TINY, "a 40 px turn did not turn the line by LOOK_SPEED of it")
	_check(_english_leaf.get_english() == Vector2(), "a plain turn moved the english")

func _the_fine_trim_holds_the_same_turn_back() -> void:
	var before := _aim_leaf.get_level_aim_deg()
	await _press_key("fine_trim", KEY_F)
	await _mouse(Vector2(40.0, 0.0))
	var delta := _aim_leaf.get_level_aim_deg() - before
	var expected := _turn_expected(40.0, _aim_leaf.tuning) * _aim_leaf.tuning.fine_scale
	_check(abs(delta - expected) < TINY, "the fine trim did not hold the same turn back to FINE_SCALE of it")
	await _release_key("fine_trim", KEY_F)

func _the_aim_never_drifts_once_settled() -> void:
	var settled := _aim_leaf.get_level_aim_deg()
	await _frames(8)
	_check(_aim_leaf.get_level_aim_deg() == settled, "the aim drifted once the mouse settled")

func _the_english_moves_the_tip_and_not_the_shot() -> void:
	var level := _aim_leaf.get_level_aim_deg()
	await _press_key("english_hold", KEY_E)
	await _mouse(Vector2(40.0, 0.0))
	await _release_key("english_hold", KEY_E)
	_check(abs(_english_leaf.get_english().x - 40.0 * _english_leaf.tuning.spin_scale_m_per_px) < 0.000000001, "the english did not move the tip to the shooter's right")
	_check(_english_leaf.get_english().y == 0.0, "the english moved the tip up as well")
	_check(_aim_leaf.get_level_aim_deg() == level, "the english moved the shot as well")

func _the_tip_stays_inside_the_miscue_disc() -> void:
	await _press_key("english_hold", KEY_E)
	await _mouse(Vector2(0.0, -300.0))
	var limit := _english_leaf.miscue_limit_m()
	var raw := 300.0 * _english_leaf.tuning.spin_scale_m_per_px
	_check(limit < raw - 0.000001, "the core's miscue limit is not under a 300 px drag")
	_check(abs(_english_leaf.get_english().y - limit) < 0.000000001, "the tip left the miscue limit as a disc instead of clamping to it")
	_check(_english_leaf.get_english().x == 0.0, "the clamp moved the tip sideways")
	_check(_english_leaf.get_english().y > 0.0, "dragging up-screen did not put the tip above the centre")
	await _release_key("english_hold", KEY_E)

func _a_new_press_resets_the_tip_to_centre() -> void:
	await _press_key("english_hold", KEY_E)
	_check(_english_leaf.get_english() == Vector2(), "a new press did not put the tip back on the centre")
	await _release_key("english_hold", KEY_E)

func _the_draw_starts_on_the_key_and_runs_on_the_mouse() -> void:
	await _press_key("cue_draw", KEY_S)
	_check(_stroke_leaf.is_charging(), "the key did not start the stroke")
	_check(_stroke_leaf.get_pull_m() == 0.0, "the stroke did not start from the rest")
	await _mouse(Vector2(0.0, 200.0))
	_check(_stroke_leaf.get_pull_m() == _stroke_leaf.tuning.max_pull_m, "a 200 px drag did not draw the cue to its cap")
	_check(_stroke_leaf.is_charging(), "the draw spent the stroke before it came home")

func _the_aim_is_left_alone_while_the_cue_is_drawn() -> void:
	var level := _aim_leaf.get_level_aim_deg()
	await _mouse(Vector2(40.0, 0.0))
	_check(_aim_leaf.get_level_aim_deg() == level, "the draw's drag turned the aim")
	_check(_stroke_leaf.is_charging(), "the draw's drag spent the stroke")

func _the_release_cancels_and_forgets_the_stroke() -> void:
	await _release_key("cue_draw", KEY_S)
	_check(_stroke_leaf.get_pull_m() == 0.0, "letting go did not forget the draw")
	_check(_stroke_leaf.get_speed_m_s() == 0.0, "a cue that never came home kept a speed over")
	_check(_shot == null, "letting go fired a shot")

func _the_flick_that_came_back_home_is_a_stroke() -> void:
	await _press_key("cue_draw", KEY_S)
	await _mouse(Vector2(0.0, 200.0))
	await _mouse(Vector2(0.0, -200.0))
	_check(_shot != null, "a cue that crossed back over home did not fire the stroke")
	if _shot == null:
		return
	_check(_shot.speed == _stroke_leaf.tuning.max_cue_speed_m_s, "a fast flick home did not reach the hardest stroke the game takes")
	_check(_shot.level_aim_deg == _aim_leaf.get_level_aim_deg(), "the shot ignored the aim the mouse had turned")
	_check(_shot.elevation_deg == 0.0, "the shot took a raise that was never asked for")
	_check(_shot.contact_x == 0.0 and _shot.contact_y == 0.0, "the shot took an english that was never left anywhere")
	_check(not _stroke_leaf.is_charging(), "the stroke could still fire twice from one flick")

func _the_aim_after_the_stroke_never_wobbles() -> void:
	var level := _aim_leaf.get_level_aim_deg()
	var tip := _english_leaf.get_english()
	await _mouse(Vector2(20.0, 0.0))
	await _mouse(Vector2(0.0, 30.0))
	_check(_aim_leaf.get_level_aim_deg() == level, "a settling mouse moved the aim once the stroke was taken")
	_check(_english_leaf.get_english() == tip, "a settling mouse moved the tip once the stroke was taken")

func _the_escape_cancels_a_charging_stroke() -> void:
	var fired_before := _shot
	await _release_key("cue_draw", KEY_S)
	await _press_key("cue_draw", KEY_S)
	await _mouse(Vector2(0.0, 60.0))
	await _press_key("cancel", KEY_ESCAPE)
	_check(_stroke_leaf.get_pull_m() == 0.0, "the cancel left the cue drawn")
	_check(not _stroke_leaf.is_charging(), "the cancel left a stroke on the way")
	_check(_shot == fired_before, "the cancel fired or dropped a shot")
	await _release_key("cue_draw", KEY_S)

func _the_raise_lifts_the_butt_not_the_line() -> void:
	_cue.rearm_after_the_settle()
	var level := _aim_leaf.get_level_aim_deg()
	var tip := _english_leaf.get_english()
	await _press_key("cue_raise", KEY_B)
	await _mouse(Vector2(0.0, 200.0))
	_check(abs(_elevation_leaf.get_cue_angle_deg() - 20.0) < 0.000000001, "holding B and dragging down did not raise the cue by ANGLE_PER_PIXEL of it")
	_check(_aim_leaf.get_level_aim_deg() == level, "the raise moved the line the mouse turned")
	_check(_english_leaf.get_english() == tip, "the raise moved the tip")
	_check(_shot != null, "the raise arrived at the shot in the core's own words")
	await _release_key("cue_raise", KEY_B)

func _the_raise_and_home_make_a_jump_shot() -> void:
	await _press_key("cue_raise", KEY_B)
	await _mouse(Vector2(0.0, 200.0))
	var raised := _elevation_leaf.get_cue_angle_deg()
	await _press_key("cue_draw", KEY_S)
	await _mouse(Vector2(0.0, 150.0))
	await _mouse(Vector2(0.0, -150.0))
	_check(_shot != null, "the raised stroke never fired")
	if _shot == null:
		return
	_check(abs(_shot.elevation_deg - raised) < TINY, "the raise never reached the stroke the core is handed")
	_check(_shot.speed == _stroke_leaf.tuning.max_cue_speed_m_s, "the flick home did not carry its power to the shot")
	await _release_key("cue_raise", KEY_B)

func _the_next_stroke_after_the_settle_fires_again() -> void:
	_cue.rearm_after_the_settle()
	await _press_key("cue_draw", KEY_S)
	await _mouse(Vector2(0.0, 100.0))
	await _mouse(Vector2(0.0, -100.0))
	_check(_shot != null, "the stroke after the settle never fired")
	_check(_shot != null and _shot.speed == _stroke_leaf.tuning.max_cue_speed_m_s, "the stroke after the settle lost its power")
