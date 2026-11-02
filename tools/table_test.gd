extends Node3D

## Headless acceptance check for issue #2's table scene: the composed meshes
## must match the counts the core geometry dictionary declares (rails, cushion
## spans, pockets, jaw faces), and every cushion segment must measure and
## centre exactly on the rail span the model says it stops at.
## Exit code 0 = pass. Run: godot --headless --path . res://tools/table_test.tscn

const TABLE_SCENE := preload("res://scenes/table/table.tscn")
const TOL := 0.0001

var _fails: Array[String] = []

func _ready() -> void:
	var geometry: Dictionary = PoolCore.new().get_table_geometry()
	var table := TABLE_SCENE.instantiate()
	_check_counts(geometry, table)
	_check_cushions(geometry, table)
	if _fails.is_empty():
		print("TABLE OK: counts follow the core dict, cushion spans exact")
	else:
		for f in _fails:
			printerr("table fail: ", f)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fails.is_empty() else 1)

func _fail(note: String) -> void:
	_fails.append(note)

func _clean(label: String) -> String:
	return label.capitalize().replace("-", "").replace(" ", "")

func _count_prefix(node: Node3D, prefix: String) -> int:
	var n := 0
	for child in node.get_children():
		if child.get_name().begins_with(prefix):
			n += 1
		elif child.get_child_count() > 0:
			# nested composition container (e.g. SteelJaws): members are one level down
			for grand in child.get_children():
				if grand.get_name().begins_with(prefix):
					n += 1
	return n

func _child_named(node: Node3D, full_name: String) -> Node3D:
	for child in node.get_children():
		if str(child.name) == full_name:
			return child
		for grand in child.get_children():
			if str(grand.name) == full_name:
				return grand
	_fail("missing node " + full_name)
	return null

func _check_counts(geometry: Dictionary, table: Node3D) -> void:
	var want_spans := 0
	for rail in geometry["rails"]:
		want_spans += (rail["spans"] as Array).size()
	var want_jaws := 0
	for pocket in geometry["pockets"]:
		want_jaws += (pocket["jaws"] as Array).size()
	if _count_prefix(table, "Rail") != (geometry["rails"] as Array).size():
		_fail("rail count does not match the dict")
	if _count_prefix(table, "Cushion") != want_spans:
		_fail("cushion count does not match the span count")
	if _count_prefix(table, "Pocket") != (geometry["pockets"] as Array).size():
		_fail("pocket count does not match the dict")
	if _count_prefix(table, "Jaw") != want_jaws:
		_fail("jaw count does not match the dict")

func _check_cushions(geometry: Dictionary, table: Node3D) -> void:
	for rail in geometry["rails"]:
		var label := _clean(String(rail["label"]))
		var tangent = rail["tangent"]
		var horizontal: bool = abs(float(tangent[0])) > 0.5
		var k := 1
		for span in (rail["spans"] as Array):
			var seg = span
			var node := _child_named(table, "Cushion" + label + str(k))
			if node != null:
				var want: float = float(seg[1]) - float(seg[0])
				var got: float = node.transform.basis.x.length()
				if not horizontal:
					got = node.transform.basis.z.length()
				if abs(got - want) > TOL:
					_fail("cushion " + label + str(k) + " length off its span")
				var centre: float = (float(seg[0]) + float(seg[1])) * 0.5
				var off: float = node.transform.origin.x
				if not horizontal:
					off = -node.transform.origin.z
				if abs(off - centre) > TOL:
					_fail("cushion " + label + str(k) + " off its span centre")
			k += 1
