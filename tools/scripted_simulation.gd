extends PoolSimulation

## A tools-only adapter double for the match play-test. The composer sees the
## real typed API; only the shot's outcome and event stream are scripted so a
## whole legal game can be driven without hunting lucky rolls. resolve() is
## inherited, so the playback path is still a real core shot with a real hash.

var _outcome := ShotOutcome.new()
var _events: Array[ShotEvent] = []


func script_next(outcome: ShotOutcome, events: Array[ShotEvent]) -> void:
	# Keep the outcome honest against its own events, as the real outcome_of
	# does: the composer folds pocketed and off-table lists from the outcome.
	for event in events:
		if event.kind == "pocket-drop" and event.ball != 0:
			outcome.pocketed.append(event.ball)
		elif event.kind == "off-table" and event.ball != 0:
			outcome.off_table.append(event.ball)
	_outcome = outcome
	_events = events


func outcome_of(_shot: PoolShot) -> ShotOutcome:
	return _outcome


func events_of(_shot: PoolShot, _rack: RackState) -> Array[ShotEvent]:
	return _events
