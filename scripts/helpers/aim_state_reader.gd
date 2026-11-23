class_name AimStateReader
extends RefCounted

## Reads one HumanShooter's current hands into the typed view hand-off. The
## leaves stay the owners of their own state; this only takes a snapshot.

static func read(shooter: HumanShooter) -> AimViewState:
	var state := AimViewState.new()
	state.level_aim_deg = shooter.get_aim_leaf().get_level_aim_deg()
	state.elevation_deg = shooter.get_elevation_leaf().get_cue_angle_deg()
	state.english = shooter.get_english_leaf().get_english()
	state.pull_m = shooter.get_stroke_leaf().get_pull_m()
	state.speed_m_s = shooter.get_stroke_leaf().get_speed_m_s()
	return state
