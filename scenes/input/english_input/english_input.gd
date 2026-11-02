
extends Node3D
class_name EnglishInput

## EnglishInput: while the hold is down the mouse moves the tip anywhere on
## the face of the cue ball, and F moves it finer. The tip is kept inside
## the miscue limit as a disc, and not the square of two clamps: out of a
## corner it would be over the limit by sqrt two, and §6.3 would miscue
## the stroke every time. The limit is the core's own - this scene takes
## the simulation as a typed injection and falls back to §6.3's number
## for a BCA ball only when no simulation has been handed in.

signal english_updated(english: Vector2)

@export var core: PoolSimulation = null

var tuning: CueTuning = CueTuning.new()

var _english := Vector2()

func english_press() -> void:
	# A new press means a new tip: the last one is not carried over.
	_english = Vector2()
	english_updated.emit(_english)

func tip_dragged(relative: Vector2, fine: bool) -> void:
	# 0.28 mm to a pixel - as little as the mouse moves it - and F holds
	# the same drag back. Right on the screen is the shooter's right.
	var step := tuning.spin_scale_m_per_px * (tuning.fine_scale if fine else 1.0)
	_english.x += relative.x * step
	_english.y -= relative.y * step
	var limit := miscue_limit_m()
	if _english.length() > limit:
		_english = _english.normalized() * limit
	english_updated.emit(_english)

func get_english() -> Vector2:
	return _english

func miscue_limit_m() -> float:
	if core != null:
		return core.miscue_limit()
	# §6.3's disc for BCA balls: 51.45% of the radius, kept here only so
	# this scene runs on its own without a simulation in the tree.
	return FALLBACK_MISCUE_M

const FALLBACK_MISCUE_M := 0.014701716211341568
