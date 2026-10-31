# Antipatterns: symptom, why it hurts, fix

| Symptom | Why it hurts | Fix |
|---|---|---|
| One script of several hundred lines with an `enum Phase` and `match phase` in `_process` | Every feature touches it; nothing is reusable; you cannot reason about one concern alone | One scene per concern. Phases become a small state machine: a `ShotFlow` node with one child node per state (`enter()`, `exit()`, `handle_input()`), or at least one script per phase |
| `_ready()` full of `MeshInstance3D.new()`, `Label.new()`, `add_child()` | Cannot see or tweak the result in the editor; styling lives in code; no reuse | Build the tree as a `.tscn`. Code only instances a PackedScene repeatedly (`ball_scene.instantiate()`) |
| `get_parent()`, `$"../Cue"`, `get_node("/root/Main/...")`, `get_tree().current_scene` | Scene only works inside one exact tree; moving a node breaks silently | Typed `@export var cue: CueStick` set by the composer, or a signal |
| Public mutable `var`s that every function reads and writes (`draw`, `pulled`, `stroke_speed`, `contact`, ...) | Hidden coupling; any code can change any state | State belongs to the scene that owns it. Others get it via signal payloads or a Resource |
| A wall of `const`s for tuning (`MAX_PULL`, `LOOK_SPEED`, ...) | Edited by code, not by the designer; duplicated | `class_name CueTuning extends Resource` with `@export` fields, saved as a `.tres`, exported by the scenes that need it |
| `Input.is_key_pressed(KEY_E)` and `event.keycode == KEY_S` | Keys hard-wired; no remapping; untestable | InputMap actions in project settings, read in a small input scene that emits intent signals |
| Same script handles input, camera, HUD text, preview geometry, playback and rules | Each chunk is a scene in disguise | Extraction map in `worked_example_pool.md` |
| Signals or functions passing `Dictionary` (`core.get_table_geometry()` result used everywhere) | No type checking, magic string keys spread through the project | One adapter node converts the raw Dictionary to a typed Resource at the border |
| Flags and methods that exist only for tests (`mouse_turns_the_shot`, `fire_now()`) | Production code carries test scaffolding; behaviour differs under test | Tests instantiate the real input scene and emit its signals, or call the public API the composer calls |
| Command-line parsing, screenshot capture, debug panel inside the game script | Dev tooling is welded to gameplay | Separate tool scenes instanced only by `main_dev.tscn` |
| `const X := preload("res://scripts/x.gd")` to avoid `class_name` | Hand-managed dependency graph | Use `class_name`; run the project import so the class cache exists |
| Long comment essays and change-history in doc comments | Hides the code; goes stale | Two lines: what and why. History belongs in git |
| Coordinate-frame conversion (`_to_godot`) called from many places | One missed call = mirrored spin | Convert only inside the physics adapter node |
| A `GameManager`/`Controller` autoload that everything calls | Global state by another name | Composer scene + signals. Autoload only with a justification |

## Before / after (shape, not code)

Before:
```
Main (game.gd, ~1000 lines: input + camera + HUD + preview + cue + playback + rules + debug)
```
After:
```
Main (composer, ~50 lines)
├── Table  ├── BallRack  ├── PoolSimulation  ├── ShotPlayback
├── CueStick  ├── AimPreview  ├── CameraRig
├── CueInput (AimInput, ElevationInput, EnglishInput, StrokeInput)
└── Hud (StatusLabel, PowerBar, DebugPanel)
```
