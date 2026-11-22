class_name InputRemap
extends RefCounted

# lint-ignore-file: use-input-map (the one place key labels are bound to InputMap events)

## Translates the short labels shown in Options to and from the InputMap events
## the game actually reads. Panels only ever pass action names and labels.

const KEY_CODES := {
	"S": KEY_S,
	"F": KEY_F,
	"E": KEY_E,
	"B": KEY_B,
	"D": KEY_D,
	"C": KEY_C,
	"Escape": KEY_ESCAPE,
	"A": KEY_A,
	"W": KEY_W,
	"Space": KEY_SPACE,
}
const KEY_LABELS := ["S", "F", "E", "B", "D", "C", "Escape", "A", "W", "Space"]


static func label_for_action(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return ""
	var key := events[0] as InputEventKey
	if key == null:
		return ""
	for label in KEY_CODES:
		if KEY_CODES[label] == key.physical_keycode:
			return str(label)
	return ""


static func apply(action: String, label: String) -> void:
	if not KEY_CODES.has(label):
		return
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_CODES[label]
	InputMap.action_add_event(action, key)
