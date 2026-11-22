extends CanvasLayer
class_name ViewHud

## The player's QoL read-outs: stroke power and an optional debug panel (D).
## Both are views: they format typed data, never read the core or judge rules.

@export var max_speed_m_s := 9.0  # m/s: the core's top stroke speed (§6.2).

var _phase := "AwaitingShot"
var _state: AimViewState


func _ready() -> void:
	$DebugPanel.visible = false


func show_view(state: AimViewState) -> void:
	_state = state
	$PowerBar.value = 100.0 * clampf(state.speed_m_s / max_speed_m_s, 0.0, 1.0)
	_refresh_debug()


func set_phase(phase: String) -> void:
	_phase = phase
	_refresh_debug()


func is_debug_open() -> bool:
	return $DebugPanel.visible


func toggle_debug() -> void:
	$DebugPanel.visible = not $DebugPanel.visible
	_refresh_debug()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		toggle_debug()


func _refresh_debug() -> void:
	if not $DebugPanel.visible:
		return
	if _state == null:
		$DebugPanel.text = "phase: " + _phase
		return
	$DebugPanel.text = "phase: %s\naim: %.1f deg\nelevation: %.1f deg\ntip: (%.4f, %.4f) m\npull: %.4f m\nspeed: %.2f m/s" % [
		_phase, _state.level_aim_deg, _state.elevation_deg,
		_state.english.x, _state.english.y, _state.pull_m, _state.speed_m_s,
	]
