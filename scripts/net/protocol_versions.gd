class_name ProtocolVersions
extends RefCounted

## Builds the HELLO frame from the engine's own build info.
##
## The server compares these fields verbatim on connect (protocol §3): a
## mismatch is a hard rejection with `version_mismatch` or `canary_mismatch`,
## never a silent downgrade. `PoolCore.get_build_info()` reports the model,
## rules/intent revisions and canary from the exact binary that will simulate
## the shot, so nothing is duplicated in GDScript. `compat/compat.json` is the
## fallback for pure-logic harnesses with no core instance.

## Wire protocol revision documented in online-multiplayer-protocol.md.
## This one is client/server contract, not an engine build property.
const PROTOCOL_VERSION := "1.0"
const COMPAT_PATH := "res://compat/compat.json"


## Engine build info, or the pinned manifest when no core is available.
static func build_info(core) -> Dictionary:
	if core != null and core.has_method("get_build_info"):
		var from_core: Variant = JSON.parse_string(String(core.get_build_info()))
		if from_core is Dictionary:
			return from_core
	if FileAccess.file_exists(COMPAT_PATH):
		var file := FileAccess.open(COMPAT_PATH, FileAccess.READ)
		var from_file: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if from_file is Dictionary:
			return from_file
	return {}


## The complete HELLO frame. `core` may be null in a pure-logic harness; in
## that case the pinned compat manifest supplies the version fields.
static func hello_fields(core, name: String) -> Dictionary:
	var info := build_info(core)
	return {
		"type": "HELLO",
		"protocol": PROTOCOL_VERSION,
		"model": str(info.get("model", "")),
		"rules": str(info.get("rules", "")),
		"intent": str(info.get("intent", "")),
		"canary": str(info.get("canary", "")),
		"name": name,
	}
