
extends Node3D
class_name StrokeInput

## StrokeInput: the key starts the cue off the ball, and the mouse carries it
## the rest of the way; the stroke is on when the cue crosses back over home,
## and the power is the tempo the cue crossed its own backswing at (§6.2:
## the cue meets the ball at twice the tempo it ran over). Letting go, or a
## cancel while the cue is out, forgets the stroke - and a stroke that never
## came home struck nothing, so its speed is no power.

signal stroke_updated(power_m_s: float)
signal stroke_released(power_m_s: float)
signal charge_forgotten()

var tuning: CueTuning = CueTuning.new()

var _charging := false
var _fired := false
var _clock := 0.0
var _motion_clock := 0.0
var _draw := 0.0
var _pulled := 0.0
var _stroke_forward := 0.0
var _stroke_clock := 0.0
var _speed := 0.0

func _process(delta: float) -> void:
	# The stroke's tempo is real time: the clock counts the frames the
	# mouse spent carrying the cue.
	_clock += delta

func start_stroke() -> void:
	# The stroke is measured from rest, and the clock runs from here: a
	# still hand between the key and the draw is not part of the stroke,
	# and the last stroke is forgotten - the bar does not carry a speed
	# over from shot to shot.
	_charging = true
	_fired = false
	_draw = 0.0
	_pulled = 0.0
	_stroke_forward = 0.0
	_stroke_clock = 0.0
	_speed = 0.0
	_motion_clock = _clock

func cancel_stroke() -> void:
	# The stroke in progress is dropped, exactly as letting go does.
	_charging = false
	_draw = 0.0
	_pulled = 0.0
	_speed = 0.0
	charge_forgotten.emit()

func draw_motion(relative: Vector2) -> void:
	if not _charging or _fired:
		return
	# The time the stroke ran over is the time of the motions that moved
	# the cue, which is what the clock counts. A motion that did not move
	# the cue adds neither: a still hand at the back of the swing costs
	# the stroke nothing.
	var since := maxf(_clock - _motion_clock, 0.0001)
	_motion_clock = _clock
	var was := _draw
	_draw = clampf(_draw + relative.y * tuning.draw_speed_m_per_px, 0.0, tuning.max_pull_m)
	if _draw > _pulled:
		# The cue is deeper than it has ever been: the run of the stroke
		# starts again, from the cue's furthest back. The backswing caps
		# the run: the cue cannot come forward further than it went back.
		_pulled = _draw
		_stroke_forward = 0.0
		_stroke_clock = 0.0
	var travelled := was - _draw
	if travelled > 0.0:
		# The cue came forward this motion, so its distance and its time
		# both count.
		_stroke_forward = minf(_stroke_forward + travelled, _pulled)
		_stroke_clock += since
		_speed = clampf(tuning.stroke_at_impact * _stroke_forward / maxf(_stroke_clock, 0.0001), tuning.min_cue_speed_m_s, tuning.max_cue_speed_m_s)
		stroke_updated.emit(_speed)
	if _pulled > 0.0 and relative.y < 0.0 and _draw <= 0.0:
		# The cue is home: the stroke is over, and the speed it crossed
		# home at is the power the shot gets. The stroke is spent; only
		# a new one on the key can take another.
		_fired = true
		stroke_released.emit(_speed)

func is_charging() -> bool:
	return _charging and not _fired

func get_pull_m() -> float:
	return _pulled

func get_speed_m_s() -> float:
	return _speed
