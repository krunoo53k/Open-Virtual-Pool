class_name ShotLog extends Resource

## A replayable snapshot of one resolved shot, taken BEFORE the rack is folded
## forward. The pre-shot rack plus the player-intent params are enough to hand
## the exact same core call to anyone; the hash, outcome and events say what it
## decided. ShotDebugLog serialises this to JSON when the player presses L.
## Nothing here simulates: every number comes from a typed object.

const FORMAT := 1

@export var model_version := 0.0  # the bridge's core model version.
@export var player := 0  # the active player at the moment of the stroke.
@export var params: ShotParams  # the stroke as the player meant it.
@export var rack: RackState  # the rack BEFORE the shot, not the settled one.
@export var hash := ""  # PoolShot.get_hash(), the determinism pin.
@export var duration := 0.0  # s: the path's own clock at its end.
@export var outcome: ShotOutcome  # the core's read-back, typed.
@export var events: Array[ShotEvent] = []  # in shot order, ball numbers.


## Capture at resolve time: the rack is still the one the core was handed.
static func capture(simulation: PoolSimulation, params: ShotParams, rack: RackState,
		shot: PoolShot, outcome: ShotOutcome, events: Array[ShotEvent], player: int) -> ShotLog:
	var log := ShotLog.new()
	log.model_version = simulation.model_version()
	log.player = player
	log.params = params.duplicate()
	log.rack = rack.duplicate_rack()
	log.hash = shot.get_hash()
	log.duration = shot.get_duration()
	log.outcome = outcome
	log.events = events.duplicate()
	return log


## Plain JSON-ready data: the flat core-frame triples are written back as
## per-ball triples (with an explicit `frame` marker), Resources become fields.
## Floats are emitted at full precision by the caller's JSON.stringify.
func to_dict() -> Dictionary:
	return {
		"format": FORMAT,
		"model_version": model_version,
		"player": player,
		"params": {
			"speed": params.speed,
			"level_aim_deg": params.level_aim_deg,
			"elevation_deg": params.elevation_deg,
			"contact_x": params.contact_x,
			"contact_y": params.contact_y,
			"called_pocket": params.called_pocket,
		},
		"rack_before": {
			"frame": "core",
			"numbers": Array(rack.numbers),
			"positions": RackState.to_triples(rack.positions),
			"rotations": RackState.to_triples(rack.rotations),
		},
		"shot": {"hash": hash, "duration": duration},
		"outcome": {
			"elapsed_time": outcome.elapsed_time,
			"phase": outcome.phase,
			"foul": outcome.foul,
			"miscue": outcome.miscue,
			"pocketed": Array(outcome.pocketed),
			"off_table": Array(outcome.off_table),
			"error": outcome.error,
		},
		"events": _events(),
	}


func _events() -> Array:
	var out: Array = []
	for event in events:
		out.append({"kind": event.kind, "time": event.time, "detail": event.detail,
			"ball": event.ball, "other": event.other})
	return out
