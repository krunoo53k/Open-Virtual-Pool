extends Node3D

## Displays the physics model version the bridge reports.
##
## This is the only scene allowed to touch `PoolCore` for display data: the
## version travels with the built extension, so what a running screen shows is
## what actually loaded. See `pool-godot` in the engine repo.

func _ready() -> void:
	refresh_label()


func refresh_label() -> void:
	var core := PoolCore.new()
	var version := core.get_model_version()
	$Label.text = "core model " + str(version)
	print("core model version: ", version)
