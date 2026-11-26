class_name ProtocolVersions
extends RefCounted

## The version triple every HELLO carries, plus the builder for that frame.
##
## The server compares these fields verbatim on connect (protocol §3): a
## mismatch is a hard rejection with `version_mismatch` or `canary_mismatch`,
## never a silent downgrade. Keep the constants in step with the server's own
## copy; a cosmetic release must not change them, only an outcome-changing one
## may bump `model` (which comes from the loaded core, not from here).

## Wire protocol revision documented in online-multiplayer-protocol.md.
const PROTOCOL_VERSION := "1"

## Revision of the shared eight-ball rules helper both sides link against.
const RULES_REV := "1"

## Revision of the shared shot-intent helper (six scalars, frames, units).
const INTENT_REV := "1"


## Build the complete HELLO frame. `core` is the loaded PoolCore instance (may
## be null in a pure-logic harness); `canary` is the string from
## DeterminismCanary.compute(). No rules, no physics — just the version triple
## the server is going to compare.
static func hello_fields(core, name: String, canary: String) -> Dictionary:
	var model := ""
	if core != null and core.has_method("get_model_version"):
		model = str(core.get_model_version())
	return {
		"type": "HELLO",
		"protocol": PROTOCOL_VERSION,
		"model": model,
		"rules": RULES_REV,
		"intent": INTENT_REV,
		"canary": canary,
		"name": name,
	}
