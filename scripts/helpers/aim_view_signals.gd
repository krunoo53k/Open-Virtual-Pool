class_name AimViewSignals
extends RefCounted

## Bridges the input leaves' intent signals to the composer-facing
## aim_state_changed on HumanShooter. Pure wiring: no rules, no physics.

static func wire(shooter: HumanShooter) -> void:
	shooter.get_aim_leaf().aim_turned.connect(func(_v: float): shooter.aim_state_changed.emit())
	shooter.get_stroke_leaf().stroke_updated.connect(func(_v: float): shooter.aim_state_changed.emit())
	shooter.get_stroke_leaf().stroke_draw_changed.connect(func(_v: float): shooter.aim_state_changed.emit())
	shooter.get_stroke_leaf().charge_forgotten.connect(func(): shooter.aim_state_changed.emit())
	shooter.get_english_leaf().english_updated.connect(func(_v: Vector2): shooter.aim_state_changed.emit())
	shooter.get_elevation_leaf().cue_raised.connect(func(_v: float): shooter.aim_state_changed.emit())
