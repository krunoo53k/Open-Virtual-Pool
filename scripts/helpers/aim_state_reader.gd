class_name AimStateReader
extends RefCounted

## Reads one aim source's current hands into the typed view hand-off. A human
## shooter exposes four leaves; a network proxy can instead hand over a ready
## snapshot. Either way the source stays the owner of its state: this only
## takes a snapshot, with no rules, physics or shot building.

static func read(shooter: Node) -> AimViewState:
	if shooter.has_method(&"get_aim_snapshot"):
		var snapshot := shooter.call(&"get_aim_snapshot") as AimViewState
		if snapshot != null:
			return snapshot
	var state := AimViewState.new()
	state.level_aim_deg = shooter.get_aim_leaf().get_level_aim_deg()
	state.elevation_deg = shooter.get_elevation_leaf().get_cue_angle_deg()
	state.english = shooter.get_english_leaf().get_english()
	state.pull_m = shooter.get_stroke_leaf().get_pull_m()
	state.speed_m_s = shooter.get_stroke_leaf().get_speed_m_s()
	return state


## For callers that already hold a typed state; no copy, just the hand-off.
static func read_state(state: AimViewState) -> AimViewState:
	return state
