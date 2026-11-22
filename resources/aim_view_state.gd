class_name AimViewState
extends Resource

## What the player's hands are doing, in one typed hand-off from the active
## HumanShooter to the display scenes. No rules, no physics: the adapter still
## owns every conversion and the rules still own every judgement.

@export var level_aim_deg := 90.0  # deg: from the long axis towards the shooter's left.
@export var elevation_deg := 0.0  # deg: the raise at the butt (player intent).
@export var english := Vector2.ZERO  # m: tip contact, to the right and above centre.
@export var pull_m := 0.0  # m: how far the cue has been drawn back.
@export var speed_m_s := 0.0  # m/s: the last stroke's speed, for the power bar.
