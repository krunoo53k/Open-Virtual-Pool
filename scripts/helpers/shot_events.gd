class_name ShotEvents
extends RefCounted

## The core reports events with ball INDICES; the rules read BALL NUMBERS.
## This conversion lives behind the adapter's door, once per shot, so nothing
## downstream ever sees an index. Rails and pockets keep their core order,
## and only ball-ball names a second ball that needs mapping (§7.3).

static func from_core(raw: Array, rack: RackState) -> Array[ShotEvent]:
	var out: Array[ShotEvent] = []
	for item in raw:
		var record: Dictionary = item
		var event := ShotEvent.new()
		event.kind = String(record.get("kind", ""))
		event.time = float(record.get("time", 0.0))
		event.detail = int(record.get("detail", 0))
		event.ball = number_of(int(record.get("a", -1)), rack)
		event.other = other_of(event.kind, int(record.get("b", -1)), rack)
		out.append(event)
	return out


static func number_of(index: int, rack: RackState) -> int:
	if index < 0 or index >= rack.numbers.size():
		return -1
	return int(rack.numbers[index])


static func other_of(kind: String, value: int, rack: RackState) -> int:
	if kind == "ball-ball":
		return number_of(value, rack)
	return value
