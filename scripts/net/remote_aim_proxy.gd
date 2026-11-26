class_name RemoteAimProxy
extends Node

## Presentation-only stand-in for the remote seat's hands.
## The six scalars live in one AimViewState; incoming AIM states are sanitized,
## then interpolated over ~100 ms from the current values to the latest one.
## There is no extrapolation, no shot building and no rule or physics call:
## the server's COMMIT alone carries the authoritative stroke.

signal aim_state_changed()

## Leaf-shaped signals exist only so the shared AimViewSignals.wire() helper
## can bind a proxy without a special case. The proxy reports changes through
## aim_state_changed; RemoteShooter forwards that to the view-facing signal.
signal aim_turned(turn_degrees: float)
signal stroke_updated(power_m_s: float)
signal stroke_draw_changed(pull_m: float)
signal charge_forgotten()
signal english_updated(english: Vector2)
signal cue_raised(raise_degrees: float)

const INTERPOLATION_SECONDS := 0.1

# Closed presentation ranges. The tip limit is the core's BCA miscue disc;
# speed's floor is the softest stroke the game accepts.
const AIM_MIN_DEG := -180.0
const AIM_MAX_DEG := 180.0
const ELEVATION_MAX_DEG := 60.0
const MISCUE_LIMIT_M := 0.01470171621134
const PULL_MAX_M := 0.30
const SPEED_MIN_M_S := 0.15
const SPEED_MAX_M_S := 9.0
const BALL_RADIUS_M := 0.028575

var _current := AimViewState.new()
var _from := AimViewState.new()
var _target := AimViewState.new()
var _elapsed := INTERPOLATION_SECONDS
var _place_preview := Vector3.ZERO


## The HumanShooter leaf interface: the proxy is its own AimInput,
## ElevationInput, EnglishInput and StrokeInput.
func get_aim_leaf() -> RemoteAimProxy:
	return self


func get_elevation_leaf() -> RemoteAimProxy:
	return self


func get_english_leaf() -> RemoteAimProxy:
	return self


func get_stroke_leaf() -> RemoteAimProxy:
	return self


func get_level_aim_deg() -> float:
	return _current.level_aim_deg


func get_cue_angle_deg() -> float:
	return _current.elevation_deg


func get_english() -> Vector2:
	return _current.english


func get_pull_m() -> float:
	return _current.pull_m


func get_speed_m_s() -> float:
	return _current.speed_m_s


## Latest-wins AIM: sanitize, then start a fresh ~100 ms run from wherever the
## picture currently is. Holding updates during playback is the composer's job.
func apply_remote(state: AimViewState) -> void:
	if state == null:
		return
	_from = _copy_of(_current)
	_target = _sanitized(state)
	_elapsed = 0.0


## Snap to a state without animating it (first sighting, resync, struck state).
func set_immediate(state: AimViewState) -> void:
	if state == null:
		return
	var clean := _sanitized(state)
	_set_current(clean)
	_target = _copy_of(clean)
	_from = _copy_of(clean)
	_elapsed = INTERPOLATION_SECONDS


func _process(delta: float) -> void:
	if _elapsed >= INTERPOLATION_SECONDS:
		return
	# Clamped at 1: a late frame finishes the run, it never overshoots it.
	_elapsed = clampf(_elapsed + maxf(delta, 0.0), 0.0, INTERPOLATION_SECONDS)
	var t := _elapsed / INTERPOLATION_SECONDS
	var next := AimViewState.new()
	next.level_aim_deg = lerpf(_from.level_aim_deg, _target.level_aim_deg, t)
	next.elevation_deg = lerpf(_from.elevation_deg, _target.elevation_deg, t)
	next.english = _from.english.lerp(_target.english, t)
	next.pull_m = lerpf(_from.pull_m, _target.pull_m, t)
	next.speed_m_s = lerpf(_from.speed_m_s, _target.speed_m_s, t)
	_set_current(next)


## The current six scalars as a snapshot for the view hand-off.
func get_state() -> AimViewState:
	return _copy_of(_current)


func snapshot() -> AimViewState:
	return get_state()


## The placement ghost's position in Godot's display frame.
func get_place_preview() -> Vector3:
	return _place_preview


## Wire `place` is a core-frame pair {x, y} with the cue's height implied.
## The inverse display map is (x, -z, y) -> core (x, y, z); going the other
## way with z = ball radius gives the one-way display vector (x, r, -y).
func apply_place_preview(place: Dictionary) -> void:
	if not place.has("x") or not place.has("y"):
		return
	var x := float(place["x"])
	var y := float(place["y"])
	if not is_finite(x) or not is_finite(y):
		return
	var core: Array[float] = [x, y, BALL_RADIUS_M]
	_place_preview = RackState.display_vector(core, 0)


func _set_current(next: AimViewState) -> void:
	if _same(next, _current):
		return
	_current = _copy_of(next)
	aim_state_changed.emit()


static func _same(a: AimViewState, b: AimViewState) -> bool:
	return (a.level_aim_deg == b.level_aim_deg
		and a.elevation_deg == b.elevation_deg
		and a.english == b.english
		and a.pull_m == b.pull_m
		and a.speed_m_s == b.speed_m_s)


static func _copy_of(state: AimViewState) -> AimViewState:
	var out := AimViewState.new()
	out.level_aim_deg = state.level_aim_deg
	out.elevation_deg = state.elevation_deg
	out.english = Vector2(state.english.x, state.english.y)
	out.pull_m = state.pull_m
	out.speed_m_s = state.speed_m_s
	return out


static func _sanitized(state: AimViewState) -> AimViewState:
	var out := AimViewState.new()
	out.level_aim_deg = _finite_clamp(state.level_aim_deg, AIM_MIN_DEG, AIM_MAX_DEG, 0.0)
	out.elevation_deg = _finite_clamp(state.elevation_deg, 0.0, ELEVATION_MAX_DEG, 0.0)
	out.english = _sanitized_tip(state.english)
	out.pull_m = _finite_clamp(state.pull_m, 0.0, PULL_MAX_M, 0.0)
	out.speed_m_s = _finite_clamp(state.speed_m_s, SPEED_MIN_M_S, SPEED_MAX_M_S, SPEED_MIN_M_S)
	return out


static func _finite_clamp(value: float, lo: float, hi: float, fallback: float) -> float:
	if not is_finite(value):
		return fallback
	return clampf(value, lo, hi)


static func _sanitized_tip(tip: Vector2) -> Vector2:
	if not is_finite(tip.x) or not is_finite(tip.y):
		return Vector2.ZERO
	if tip.length() > MISCUE_LIMIT_M:
		return tip.normalized() * MISCUE_LIMIT_M
	return Vector2(tip.x, tip.y)
