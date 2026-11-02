class_name InputActions
extends RefCounted

# lint-ignore-file: use-input-map (the one place keys are bound to actions)

## Binds the game's actions once at startup, so headless runs and scenes built
## without the editor all have them. A binding that already exists is left
## alone, which makes calling this from more than one place safe.

const DEFAULTS := {
	"cue_draw": KEY_S,
	"cue_raise": KEY_B,
	"english_hold": KEY_E,
	"fine_trim": KEY_F,
	"debug_toggle": KEY_D,
	"camera_toggle": KEY_C,
	"cancel": KEY_ESCAPE,
}

static func register_defaults() -> void:
	for action in DEFAULTS:
		if InputMap.has_action(action):
			continue
		# the cheat-sheet shape: physical keys, so the action means the same
		# on any layout.
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = DEFAULTS[action]
		# lint-ignore: use-input-map (this is the one binding table)
		InputMap.action_add_event(action, key)
