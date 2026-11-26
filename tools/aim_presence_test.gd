extends Node3D

## Headless acceptance harness for C4 opponent presence: the proxy's leaf
## interface, six-scalar interpolation, hostile-value sanitization, the
## placement ghost's core -> display conversion, and the RemoteShooter script
## swap OnlineMatch performs. Exit code is the number of failed assertions.

const REMOTE_SCENE := preload("res://scenes/input/remote_shooter/remote_shooter.tscn")
const HUMAN_SCENE := preload("res://scenes/input/human_shooter/human_shooter.tscn")
const REMOTE_SCRIPT := preload("res://scenes/input/remote_shooter/remote_shooter.gd")

class SnapshotSource extends Node:
	var state: AimViewState

	func get_aim_snapshot() -> AimViewState:
		return state


var _fails: Array[String] = []
var _changes := 0
var _shooter_changes := 0
var _last_shot: ShotParams = null


func _ready() -> void:
	var proxy := RemoteAimProxy.new()
	_leaf_interface(proxy)
	var start := _state(10.0, 5.0, Vector2(0.002, -0.003), 0.1, 2.0)
	proxy.set_immediate(start)
	_check(_same(proxy.get_state(), start), "get_state exposes the proxy's current snapshot")
	_check(_same(proxy.snapshot(), start), "snapshot aliases the current state")
	_check(_same(AimStateReader.read(proxy), start),
		"AimStateReader.read returns all six scalars from the proxy's leaves")

	_interpolation(proxy, start)
	_sanitization(proxy)
	_snapshot_preference()
	_placement_ghost(proxy)
	_remote_shooter()
	_script_swap()

	if _fails.is_empty():
		print("AIM PRESENCE OK: leaf interface, interpolation, sanitization, ghost and script swap hold")
	else:
		for f in _fails:
			printerr("aim presence said no: ", f)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fails.is_empty() else 1)


func _leaf_interface(proxy: RemoteAimProxy) -> void:
	_check(proxy.get_aim_leaf() == proxy, "the aim leaf is the proxy itself")
	_check(proxy.get_elevation_leaf() == proxy, "the elevation leaf is the proxy itself")
	_check(proxy.get_english_leaf() == proxy, "the english leaf is the proxy itself")
	_check(proxy.get_stroke_leaf() == proxy, "the stroke leaf is the proxy itself")


func _interpolation(proxy: RemoteAimProxy, start: AimViewState) -> void:
	var target := _state(50.0, 25.0, Vector2(0.010, 0.0), 0.2, 6.0)
	_changes = 0
	proxy.aim_state_changed.connect(_on_proxy_changed)
	proxy.apply_remote(target)
	proxy._process(0.025)
	var mid := AimStateReader.read(proxy)
	_moves(start.level_aim_deg, mid.level_aim_deg, target.level_aim_deg, "level aim")
	_moves(start.elevation_deg, mid.elevation_deg, target.elevation_deg, "elevation")
	_moves(start.english.x, mid.english.x, target.english.x, "english x")
	_moves(start.english.y, mid.english.y, target.english.y, "english y")
	_moves(start.pull_m, mid.pull_m, target.pull_m, "pull")
	_moves(start.speed_m_s, mid.speed_m_s, target.speed_m_s, "speed")
	_check(_changes > 0, "a changed interpolated value emits aim_state_changed")

	for _i in range(3):
		proxy._process(0.025)
	_check(_same(AimStateReader.read(proxy), target), "interpolation lands exactly on the target at 100 ms")
	var at_end := _changes
	proxy._process(0.05)
	_check(_changes == at_end, "no further changes after the run ends")
	_check(_same(AimStateReader.read(proxy), target), "a late frame never extrapolates past the target")


func _sanitization(proxy: RemoteAimProxy) -> void:
	var hostile := _state(1.0e12, -1.0e12, Vector2(1000.0, -1000.0), 5.0, -5.0)
	proxy.set_immediate(hostile)
	var s := AimStateReader.read(proxy)
	_check(s.level_aim_deg == 180.0, "hostile aim clamps to +180")
	_check(s.elevation_deg == 0.0, "hostile elevation clamps to zero")
	_check(absf(s.english.length() - RemoteAimProxy.MISCUE_LIMIT_M) < 0.0000001,
		"hostile english clamps to the core's miscue disc")
	_check(s.english.x > 0.0 and s.english.y < 0.0, "the tip clamp keeps the hostile direction")
	_check(s.pull_m == 0.30, "hostile pull clamps to the 0.30 m maximum")
	_check(s.speed_m_s == 0.15, "hostile speed clamps to the 0.15 m/s minimum")

	var non_finite := _state(NAN, INF, Vector2(NAN, 1.0), INF, NAN)
	proxy.set_immediate(non_finite)
	s = AimStateReader.read(proxy)
	_check(s.level_aim_deg == 0.0, "a non-finite aim falls back to zero")
	_check(s.elevation_deg == 0.0, "a non-finite elevation falls back to zero")
	_check(s.english == Vector2.ZERO, "a non-finite tip falls back to the centre")
	_check(s.pull_m == 0.0, "a non-finite pull falls back to rest")
	_check(s.speed_m_s == 0.15, "a non-finite speed falls back to the slowest stroke")


func _snapshot_preference() -> void:
	var source := SnapshotSource.new()
	source.state = _state(-42.0, 12.0, Vector2(0.004, 0.005), 0.07, 4.5)
	var via_snapshot := AimStateReader.read(source)
	_check(_same(via_snapshot, source.state), "read prefers get_aim_snapshot when the source has it")
	_check(AimStateReader.read_state(via_snapshot) == via_snapshot,
		"read_state passes an existing state through")


func _placement_ghost(proxy: RemoteAimProxy) -> void:
	var layout := TableLayout.new()
	proxy.apply_place_preview({"x": 0.6, "y": -0.2})
	_check(proxy.get_place_preview() == Vector3(0.6, layout.ball_radius, 0.2),
		"a core-frame place maps to the Godot display vector (x, radius, -y)")
	var held := proxy.get_place_preview()
	proxy.apply_place_preview({"x": NAN, "y": 0.1})
	_check(proxy.get_place_preview() == held, "a non-finite place leaves the ghost where it was")


func _remote_shooter() -> void:
	var shooter: RemoteShooter = REMOTE_SCENE.instantiate()
	add_child(shooter)
	_check(shooter.aim_proxy != null, "the remote scene carries an AimProxy")
	_check(shooter.get_aim_proxy() == shooter.aim_proxy, "get_aim_proxy exposes the child proxy")
	shooter.aim_state_changed.connect(_on_shooter_changed)
	var hand := _state(30.0, 8.0, Vector2(0.001, 0.0), 0.05, 3.0)
	shooter.aim_proxy.set_immediate(hand)
	_check(_shooter_changes > 0, "proxy changes reach the shooter's aim_state_changed for AimView")
	_check(_same(shooter.get_aim_snapshot(), hand), "get_aim_snapshot hands the proxy's six scalars to the view")
	_check(_same(AimStateReader.read(shooter), hand), "AimStateReader reads a RemoteShooter through the snapshot")

	_last_shot = null
	shooter.shot_committed.connect(_capture_shot)
	var event := InputEventKey.new()
	event.keycode = KEY_S
	event.pressed = true
	shooter._unhandled_input(event)
	_check(_last_shot == null, "an input event never fires a remote stroke")
	var params := ShotParams.new()
	params.speed = 3.0
	shooter.commit_remote(params)
	_check(_last_shot == params, "commit_remote announces the authoritative params on shot_committed")
	shooter.rearm_after_the_settle()
	_check(_last_shot == params, "rearm_after_the_settle emits no extra stroke")


func _script_swap() -> void:
	var node := HUMAN_SCENE.instantiate()
	node.set_script(REMOTE_SCRIPT)
	add_child(node)
	var swapped := node as RemoteShooter
	_check(swapped != null, "a script swapped onto a human shooter becomes a RemoteShooter")
	if swapped == null:
		return
	_check(swapped.get_node_or_null("AimProxy") != null, "a swapped node creates its own AimProxy in _ready")
	_check(swapped.get_aim_proxy() == swapped.aim_proxy, "the swapped node exposes the new proxy")
	var hand := _state(12.0, 3.0, Vector2.ZERO, 0.02, 1.5)
	swapped.aim_proxy.set_immediate(hand)
	_check(_same(swapped.get_aim_snapshot(), hand), "a swapped node reads its remote hands through the snapshot")


func _state(aim: float, elevation: float, english: Vector2, pull: float, speed: float) -> AimViewState:
	var state := AimViewState.new()
	state.level_aim_deg = aim
	state.elevation_deg = elevation
	state.english = english
	state.pull_m = pull
	state.speed_m_s = speed
	return state


func _same(a: AimViewState, b: AimViewState) -> bool:
	return (a != null and b != null
		and a.level_aim_deg == b.level_aim_deg
		and a.elevation_deg == b.elevation_deg
		and a.english == b.english
		and a.pull_m == b.pull_m
		and a.speed_m_s == b.speed_m_s)


func _moves(before: float, now: float, target: float, note: String) -> void:
	_check(now > before and now < target,
		"%s moved toward the target but never past it" % note)


func _capture_shot(params: ShotParams) -> void:
	_last_shot = params


func _on_proxy_changed() -> void:
	_changes += 1


func _on_shooter_changed() -> void:
	_shooter_changes += 1


func _check(ok: bool, note: String) -> void:
	if not ok:
		_fails.append(note)
