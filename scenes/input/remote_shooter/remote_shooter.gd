extends HumanShooter
class_name RemoteShooter

## The remote seat's stand-in. It keeps the exact leaf tree a HumanShooter has
## so swapping this script onto an existing Shooter node needs no scene edit,
## but it never forwards an input event: the opponent's visible hands come
## from AIM/PLACE_PREVIEW and the strike comes from the authoritative COMMIT.

var aim_proxy: RemoteAimProxy = null


func _ready() -> void:
	# OnlineMatch swaps this script onto an existing human_shooter.tscn node
	# before add_child, so there is no AimProxy child yet. Create it before the
	# parent wires the leaves: the real leaves stay in place for that wiring,
	# while the remote hands are handed to the view as a typed snapshot.
	ensure_aim_proxy()
	# Keeps the shared leaf wiring and typed injections the scene expects.
	super._ready()


func get_aim_proxy() -> RemoteAimProxy:
	return ensure_aim_proxy()


## Also covers a script swapped onto a node whose _ready already ran.
func ensure_aim_proxy() -> RemoteAimProxy:
	if aim_proxy == null or not is_instance_valid(aim_proxy):
		aim_proxy = get_node_or_null("AimProxy") as RemoteAimProxy
		if aim_proxy == null:
			aim_proxy = RemoteAimProxy.new()
			aim_proxy.name = "AimProxy"
			add_child(aim_proxy)
	if not aim_proxy.aim_state_changed.is_connected(_on_proxy_state_changed):
		aim_proxy.aim_state_changed.connect(_on_proxy_state_changed)
	return aim_proxy


## The view prefers this typed hand-off over the parent's local leaves: the
## proxy owns the remote seat's six scalars, while the inherited leaf getters
## keep returning the real leaf nodes the scene was built with.
func get_aim_snapshot() -> AimViewState:
	return ensure_aim_proxy().get_state()


func _unhandled_input(_event: InputEvent) -> void:
	# No local gesture ever becomes a remote seat's input or shot.
	pass


## The server's committed params travel through the same typed channel as a
## local stroke so MatchFlow needs no second path.
func commit_remote(params: ShotParams) -> void:
	shot_committed.emit(params)


func rearm_after_the_settle() -> void:
	# Nothing to re-arm: the next remote stroke arrives as another COMMIT.
	pass


func _on_proxy_state_changed() -> void:
	aim_state_changed.emit()
