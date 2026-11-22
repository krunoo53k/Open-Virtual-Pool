class_name PlacementHelper
extends RefCounted

## Dev-only spot search shared by the headless harnesses: find a patch of cloth
## well clear of every ball, then drive the real public placement entry.

static func clean_spot(layout: TableLayout, rack: RackState) -> Vector3:
	var r := layout.ball_radius
	for i in range(12):
		for j in range(6):
			var p := Vector3(layout.length * (0.07 + 0.075 * i), r,
				-layout.width * (0.1 + 0.16 * j))
			var clear := true
			for other in rack.positions:
				var flat := Vector2(p.x - other.x, p.z - other.z)
				if flat.length() < 4.0 * r:
					clear = false
					break
			if clear:
				return p
	return Vector3(layout.length * 0.5, r, -layout.width * 0.5)


static func place_cue(input: BallInHandInput, layout: TableLayout, rack: RackState) -> bool:
	return input.place_at(clean_spot(layout, rack))
