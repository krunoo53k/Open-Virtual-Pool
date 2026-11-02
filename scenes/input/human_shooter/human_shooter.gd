
extends Node3D
class_name HumanShooter

## HumanShooter: the tree's human-input model. This scene wires AimInput,
## StrokeInput, EnglishInput, ElevationInput and CancelInput, and it owns
## the routing order the playground ran with: the tip wins when the hold
## for it is down, the draw wins over the raise, and the mouse turns the
## line only when none of the other gestures wants the drag. What each
## gesture means stays inside its own scene; here, the mouse is only put
## to work. The shot is prepared exactly once, when the cue has crossed
## home, as one typed ShotParams the table can take.

@export var core: PoolSimulation = null

signal shot_prepared(params: ShotParams)

var tuning: CueTuning = CueTuning.new()

var _shot_taken := false

func _ready() -> void:
	InputActions.register_defaults()
	$EnglishInput.core = core
	$CancelInput.cancel_requested.connect(_on_cancel_requested)
	$StrokeInput.stroke_released.connect(_on_stroke_released)

func get_aim_leaf() -> AimInput:
	return $AimInput

func get_stroke_leaf() -> StrokeInput:
	return $StrokeInput

func get_english_leaf() -> EnglishInput:
	return $EnglishInput

func get_elevation_leaf() -> ElevationInput:
	return $ElevationInput

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_route_mouse(event)
	else:
		_route_key(event)

func _route_mouse(event: InputEventMouseMotion) -> void:
	if _shot_taken:
		# The stroke is on: the aim and the tip are the player's last
		# look, and the mouse only settles their hand. A flick that
		# takes the stroke is a big, fast drag, and its sideways
		# wobble used to turn the aim as well - so the deviation
		# came out proportional to the force of the flick, exactly
		# what the player keeps reporting. The shot that goes is
		# the one they looked at.
		return
	var fine := Input.is_action_pressed("fine_trim")
	if Input.is_action_pressed("english_hold"):
		# The tip moves on the face of the ball, and the aim is left
		# alone. This branch comes before the draw and the raise, so
		# a player holding more than one key is looking at the tip
		# they are moving.
		$EnglishInput.tip_dragged(event.relative, fine)
	elif Input.is_action_pressed("cue_draw"):
		$StrokeInput.draw_motion(event.relative)
	elif Input.is_action_pressed("cue_raise"):
		$ElevationInput.raise_dragged(event.relative)
	else:
		$AimInput.aim_dragged(event.relative, fine)

func _route_key(event: InputEvent) -> void:
	if event.is_action_pressed(&"cue_draw") and Input.is_action_just_pressed(&"cue_draw"):
		# The cue is drawn back: the shot is on when the cue comes back
		# to the ball, so the key never has to be let go of.
		_shot_taken = false
		$StrokeInput.start_stroke()
	elif event.is_action_released(&"cue_draw") and $StrokeInput.is_charging():
		$StrokeInput.cancel_stroke()
	elif event.is_action_pressed(&"english_hold") and Input.is_action_just_pressed(&"english_hold"):
		$EnglishInput.english_press()

func _on_cancel_requested() -> void:
	# The cancel drops the stroke in progress just as letting go of the
	# key does; a stroke that is already over cannot be dropped twice.
	if $StrokeInput.is_charging():
		$StrokeInput.cancel_stroke()

func _on_stroke_released(power_m_s: float) -> void:
	var shot := ShotParams.new()
	shot.speed = power_m_s
	shot.level_aim_deg = $AimInput.get_level_aim_deg()
	shot.elevation_deg = $ElevationInput.get_cue_angle_deg()
	var tip: Vector2 = $EnglishInput.get_english()
	shot.contact_x = tip.x
	shot.contact_y = tip.y
	_shot_taken = true
	shot_prepared.emit(shot)

func rearm_after_the_settle() -> void:
	# The table has settled: the next stroke can start, and it starts
	# where the player left the aim and the tip.
	_shot_taken = false
