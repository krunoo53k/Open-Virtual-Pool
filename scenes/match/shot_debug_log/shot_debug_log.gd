extends Node
class_name ShotDebugLog

## Writes the last captured shot to user:// as JSON. The bind belongs to
## ShotLogInput; this scene only stores the typed snapshot and serialises it,
## so a bugged shot can be handed over with its exact params and pre-shot rack.

@export var path := "user://last_shot.json"  # where the dump lands.

var _last: ShotLog


func capture(log: ShotLog) -> void:
	_last = log


func has_shot() -> bool:
	return _last != null


## The written path, or "" when there was no shot or the file could not open.
func dump() -> String:
	if _last == null:
		print("shot log: no shot captured yet")
		return ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("shot log: could not open " + path)
		return ""
	# Full precision: the hash is byte-exact, so a shortened float would make
	# a replay disagree with the shot the player actually saw.
	file.store_string(JSON.stringify(_last.to_dict(), "  ", false, true))
	file.close()
	var absolute := ProjectSettings.globalize_path(path)
	print("shot log saved: ", absolute)
	return absolute
