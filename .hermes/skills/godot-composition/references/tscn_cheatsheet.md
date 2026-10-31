# .tscn and project cheatsheet (Godot 4)

## Hand-writing a scene

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/ball/ball.gd" id="1_ball"]
[ext_resource type="PackedScene" path="res://scenes/ball/ball.tscn" id="2_ball"]

[sub_resource type="SphereMesh" id="SphereMesh_a"]
radius = 0.028575
height = 0.05715

[node name="BallRack" type="Node3D"]
script = ExtResource("1_ball")

[node name="Mesh" type="MeshInstance3D" parent="."]
mesh = SubResource("SphereMesh_a")

[node name="Ball1" parent="." instance=ExtResource("2_ball")]

[connection signal="shot_committed" from="CueInput" to="." method="_on_cue_input_shot_committed"]
```

Notes:
- `uid=` and `load_steps=` are optional; Godot fills them in when the editor saves the scene.
- Every `id` is unique within the file; sub-resource and ext-resource ids are separate namespaces.
- A child of the root has `parent="."`; a grandchild has `parent="Child"` (path from the root).
- Instanced scenes have `instance=ExtResource(...)` and no `type=`.
- Properties for an instanced child (overrides) follow its `[node ...]` line.
- `[connection ...]` lines go at the end of the file and are checked at load time.
- Exports that point at nodes appear as `some_export = NodePath("Child")`.

## Typed exports that hold dependencies

```gdscript
@export var tuning: CueTuning          # a Resource, set in the inspector
@export var simulation: PoolSimulation # a node in the same scene tree
```

Use these for things the scene needs. If the composer wires them in `_ready()`, add `assert(tuning != null, "CueInput needs a CueTuning")` at the top of the scene's `_ready()` so a missing dependency fails loudly.

## Resource class

```gdscript
class_name ShotParams
extends Resource

@export var aim: Vector3 = Vector3.RIGHT
@export var elevation_deg: float = 0.0
@export var contact: Vector2 = Vector2.ZERO
@export var speed: float = 0.0
```

## Class cache and `class_name`

`class_name` types are registered by the editor/import step. In a fresh checkout or after adding a `class_name` file, run the import once so headless runs can see them (flags can vary by Godot version; check `godot --help`):

```
godot --headless --path <project_dir> --import
```

Do not work around a missing cache with `preload("res://x.gd")`.

## Headless checks (if a Godot binary is available)

```
# parse all scripts and load the project, then quit
godot --headless --path <project_dir> --quit
# run one scene alone for a few frames
godot --headless --path <project_dir> res://scenes/cue_stick/cue_stick.tscn --quit-after 30
# syntax-check one script
godot --headless --path <project_dir> --check-only -s res://scenes/cue_stick/cue_stick.gd
```

Read the output for `SCRIPT ERROR`, `Parse Error` and `Invalid`. If no binary is available, say so in the report and rely on the lint.

## InputMap actions

Read actions with `Input.is_action_pressed("fine_trim")` or `event.is_action_pressed("camera_toggle")` in `_unhandled_input`. Two ways to define them:

1. **Editor / `project.godot` `[input]`.** Best when a human is using the editor. The serialized event format is long and version-dependent, so avoid hand-writing it.
2. **One helper that registers defaults at startup** (best for agents and headless runs):

```gdscript
class_name InputActions
extends RefCounted

const DEFAULTS := {
	"cue_draw": KEY_S,
	"fine_trim": KEY_F,
}

static func register_defaults() -> void:
	for action in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = DEFAULTS[action]
		InputMap.action_add_event(action, key)
```

Call it from the composer's `_ready()`. The raw `KEY_*` constants live in this one file (add `# lint-ignore-file: use-input-map (the one place keys are bound)` to it). Tests then drive the game with `Input.parse_input_event(InputEventAction.new())` (set `action` and `pressed`) plus mouse-motion events.

## Folder convention

```
scenes/<name>/<name>.tscn
scenes/<name>/<name>.gd
resources/<name>.tres
scripts/helpers/<name>.gd   # pure static helpers, no node
tools/                      # dev-only scenes
```
