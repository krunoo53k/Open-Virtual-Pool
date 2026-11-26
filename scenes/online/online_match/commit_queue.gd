class_name CommitQueue
extends RefCounted

## Ordered COMMIT queue. The server sends one commit per shot; a commit for
## turn N+1 can arrive while turn N is still animating. Inserts stay sorted by
## sequence number, duplicates are ignored, and stale commits (already
## confirmed) are dropped so a reconnect cannot replay an old shot.

var _items: Array[Dictionary] = []


func push(message: Dictionary) -> bool:
	var seq := int(message.get("seq", -1))
	if seq < 0 or has_seq(seq):
		return false
	for i in _items.size():
		if int(_items[i].get("seq", -1)) > seq:
			_items.insert(i, message)
			return true
	_items.append(message)
	return true


func has_seq(seq: int) -> bool:
	for item in _items:
		if int(item.get("seq", -1)) == seq:
			return true
	return false


func peek() -> Dictionary:
	if _items.is_empty():
		return {}
	return _items[0]


func pop() -> Dictionary:
	if _items.is_empty():
		return {}
	return _items.pop_front()


func drop_stale(confirmed_seq: int) -> void:
	var kept: Array[Dictionary] = []
	for item in _items:
		if int(item.get("seq", -1)) > confirmed_seq:
			kept.append(item)
	_items = kept


func size() -> int:
	return _items.size()


func clear() -> void:
	_items.clear()
