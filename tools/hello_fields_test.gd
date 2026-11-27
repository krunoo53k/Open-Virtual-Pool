extends Node

## HELLO must come from the loaded engine's build info, not from a GDScript
## copy that can drift away from compat/compat.json. Checks both the live-core
## path and the manifest fallback. Exit code = failed assertions.

const COMPAT_PATH := "res://compat/compat.json"

var _fails := 0


func _ready() -> void:
	var core := PoolCore.new()
	if not core.has_method("get_build_info"):
		printerr("  FAIL: the pinned engine does not expose get_build_info()")
		get_tree().quit(1)
		return
	var info: Variant = JSON.parse_string(String(core.get_build_info()))
	_check(info is Dictionary, "build info parses")
	var hello := ProtocolVersions.hello_fields(core, "Tester")
	for field in ["model", "rules", "intent", "canary"]:
		_check(str(hello.get(field, "")) == str(info.get(field, "")),
			"HELLO " + field + " matches the loaded engine")
	_check(str(hello.get("protocol", "")) == ProtocolVersions.PROTOCOL_VERSION,
		"HELLO protocol uses the wire contract version")
	_check(str(hello.get("name", "")) == "Tester", "HELLO carries the player name")

	var file := FileAccess.open(COMPAT_PATH, FileAccess.READ)
	_check(file != null, "compat manifest is readable")
	if file != null:
		var manifest: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		_check(manifest is Dictionary, "compat manifest parses")
		if manifest is Dictionary:
			for field in ["model", "rules", "intent", "canary"]:
				_check(str(hello.get(field, "")) == str(manifest.get(field, "")),
					"HELLO " + field + " matches the compat pin")
			_check(str(manifest.get("protocol", "")) == ProtocolVersions.PROTOCOL_VERSION,
				"compat protocol matches the wire contract")
	var fallback := ProtocolVersions.hello_fields(null, "Tester")
	for field in ["model", "rules", "intent", "canary"]:
		_check(str(fallback.get(field, "")) == str(hello.get(field, "")),
			"manifest fallback agrees with the engine for " + field)
	print("hello fields: ", _fails, " failed assertions")
	get_tree().quit(_fails)


func _check(ok: bool, note: String) -> void:
	if ok:
		print("  PASS: ", note)
	else:
		_fails += 1
		printerr("  FAIL: ", note)
