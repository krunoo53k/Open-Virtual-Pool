extends Node3D
class_name ShotPlayback

## Plays one resolved PoolShot: balls are instances of the ball scene, laid
## frame by frame straight off the core's path. Never physics: the path is
## the adapter's answer, sampling it is the only job here. `play` builds the
## ball set from a `RackState` and lays frame zero; `step` advances an
## internal clock that clamps exactly at the shot's duration; `path_finished`
## fires once when the clock lands.

const BALL_SCENE := preload("res://scenes/rack/ball/ball.tscn")

@export var time_scale := 1.0  # replay speed multiplier; 1.0 is real time.
@export var ball_radius_m := 0.028575  # m: how big the replayed balls are.

signal path_finished(shot: PoolShot)

var _path  # the shot under replay (null until play).
var _duration := 0.0  # s: where the clock must land, never past.
var _clock := 0.0  # s: the replay's own clock.
var _fired := false  # path_finished has been emitted once.
var _balls := []  # the instanced Ball nodes, in rack order.


func play(path: PoolShot, rack: RackState) -> void:
	_path = path
	_duration = path.get_duration()
	_clock = 0.0
	_fired = false
	_balls.clear()
	for i in rack.numbers.size():
		# number and radius first: the ball paints on entry to the tree.
		var ball := BALL_SCENE.instantiate()
		ball.number = rack.numbers[i]
		ball.radius_m = ball_radius_m
		add_child(ball)
		_balls.append(ball)
	_lay_frame()


func step(delta_seconds: float) -> void:
	# a view that never got a shot stays still.
	if _path == null:
		return
	_clock = minf(_clock + delta_seconds * time_scale, _duration)
	_lay_frame()
	if _clock >= _duration and not _fired:
		_fired = true
		path_finished.emit(_path)


func is_finished() -> bool:
	# the clamp parks the clock at the duration and never past it.
	return _clock >= _duration


func get_elapsed() -> float:
	return _clock


func _process(delta: float) -> void:
	step(delta)


func _lay_frame() -> void:
	# positions and orientations sampled straight off the trace; the ball
	# scene takes axis-times-angle rotations verbatim (§11.2's carry).
	var positions = _path.sample(_clock)
	var rotations = _path.sample_rotation(_clock)
	for i in _balls.size():
		_balls[i].place(positions[i], rotations[i])
