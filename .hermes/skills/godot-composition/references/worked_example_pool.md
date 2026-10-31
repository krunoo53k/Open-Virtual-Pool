# Worked example: a pool game, from one big script to scenes

(If this repo has `pool-godot/`, also read `pool_project_context.md`: it maps the real `PoolCore`/`PoolShot` API onto the types below.)

Source situation: a Godot 4 game whose single `game.gd` (about a thousand lines) did everything. A Rust GDExtension (`PoolCore`) resolves a shot in one call and returns the path of every ball; Godot only renders. Controls: mouse turns the aim, hold a key and drag to draw the cue back (stroke speed is the power), another key raises the cue, another moves the tip on the cue ball (english), another finer trim.

## Target tree

```
Main (main.tscn, composer script ~50 lines)
├── Table                 table.tscn          cloth, cushions, pockets, lights
├── BallRack              ball_rack.tscn      instances Ball x16, applies poses and outcomes
│   └── Ball              ball.tscn           mesh + number texture, place(pos, rot)
├── PoolSimulation        pool_simulation.tscn  the ONLY node touching PoolCore
├── ShotPlayback          shot_playback.tscn  advances time over a PoolShot
├── CueStick              cue_stick.tscn      3D cue model (view)
├── AimPreview            aim_preview.tscn    line, ghost ball, tip marker (view)
├── CameraRig             camera_rig.tscn     CueCamera, TableCamera, toggle
├── CueInput              cue_input.tscn      composes the four inputs into a draft shot
│   ├── AimInput          aim_input.tscn      mouse -> aim direction
│   ├── ElevationInput    elevation_input.tscn  drag -> cue angle
│   ├── EnglishInput      english_input.tscn  drag -> tip offset on the ball
│   └── StrokeInput       stroke_input.tscn   draw back / push forward -> speed
├── ShotFlow              shot_flow.tscn      Aiming / Charging / Striking / Rolling states
└── Hud                   hud.tscn            StatusLabel, PowerBar, VersionStamp, DebugPanel
```

Dev-only: `main_dev.tscn` instances `main.tscn` plus `ScreenshotCapture` (reads `--screenshot`).

## Resources

| class_name | Fields |
|---|---|
| `ShotParams` | `aim: Vector3`, `elevation_deg: float`, `contact: Vector2`, `speed: float` |
| `ShotPreview` | `ghost_position: Vector3`, `has_hit: bool`, `hit_ball_number: int`, `leave_direction: Vector3`, `elevation_deg: float` |
| `ShotOutcome` | typed copy of the core's final state: `elapsed_time`, `foul`, `miscue`, `pocketed`, `off_table`. The path itself stays a `PoolShot`, which is already a typed class |
| `CueTuning` | `max_pull`, `max_cue_speed`, `angle_per_pixel`, `look_speed`, `fine_scale`, `draw_speed`, `spin_scale`, `max_cue_angle`, ... same values as the old consts |
| `TableLayout` | `length`, `width`, `ball_radius`, `cue_spot` (typed copy of the core's geometry Dictionary) |

## Signals and wiring (all done in Main)

| Emitter | Signal | Receiver (connected by Main) |
|---|---|---|
| AimInput | `aim_turned(direction: Vector3)` | CueInput (internal) |
| ElevationInput | `elevation_changed(degrees: float)` | CueInput (internal) |
| EnglishInput | `english_changed(offset: Vector2)` | CueInput (internal) |
| StrokeInput | `charge_started()`, `charge_cancelled()`, `stroke_updated(speed: float, pulled: float)`, `stroke_released(speed: float)` | CueInput (internal) |
| CueInput | `draft_changed(draft: ShotParams)` | Main -> `PoolSimulation.preview(draft)` -> `AimPreview.show_preview`, `CueStick.set_pose`, `CameraRig.follow_aim`, `Hud.show_draft` |
| CueInput | `shot_committed(params: ShotParams)` | Main -> `ShotFlow.begin_strike(params)` |
| ShotFlow | `strike_finished(params: ShotParams)` | Main -> `PoolSimulation.resolve(params, rack.state())` -> `ShotPlayback.play(shot)` |
| ShotPlayback | `frame_ready(positions: PackedVector3Array, rotations: PackedVector3Array)` | `BallRack.apply_poses` |
| ShotPlayback | `playback_finished(shot: PoolShot)` | `BallRack.apply_outcome(shot)`, `CueInput.reset()` |

`CueInput` is only one producer of `ShotParams`: an AI opponent or a replay can emit `shot_committed` the same way, and the composer does not care which. For tests, expose the composer's `take_shot(params)` instead of a test-only `fire_now()`.

`CueInput.reset()` is where the old `_settle()` put the tip back to centre and the cue back flat: each input scene resets its own state.

## Extraction map: where each part of the old script went

| Old code | New home |
|---|---|
| `_build_world`, `_build_balls`, rack positions | `table.tscn`, `ball_rack.tscn`, `ball.tscn` (static parts as scene files) |
| `_build_cue`, `_update_cue`, `_tip`, `_basis_along_y` | `cue_stick.tscn` (`set_pose(tip, aim, pull)`) |
| `_draw_aim`, `_first_contact`, `_to_the_edge`, `_update_aim_visibility` | `aim_preview.tscn` (shows a `ShotPreview`); the ray test sits behind `PoolSimulation.preview()` |
| `_build_camera`, `_update_camera`, `camera_mode`, camera vars | `camera_rig.tscn` |
| `_build_status`, `_update_status`, `_aiming_status`, `_cue_words`, `_draw_power` | `hud.tscn`; wording lives in a pure helper `ShotWords` (static functions, no node) |
| `_update_debug`, `_debug_the_shot`, `_debug_the_run`, `_spin_words`, `_events_words`, `_vector`, `_trace_velocity` | `debug_panel.tscn` (child of Hud) plus `ShotWords` |
| `_unhandled_input`, `_mouse_motion`, `_key` | The four input scenes; keys become InputMap actions (`aim_turn`, `cue_draw`, `cue_raise`, `english_hold`, `fine_trim`, `camera_toggle`, `debug_toggle`) |
| `enum Phase` + `match phase` in `_process` | `shot_flow.tscn` with one child node per state |
| `_fire`, `_play_back`, `shot_time` | `PoolSimulation.resolve()` and `shot_playback.tscn` |
| `_settle`, `live`, `off_table`, `pocketed`, `carried_rotation` | `ball_rack.tscn` (`apply_outcome`) |
| `_to_godot` coordinate conversion | inside `pool_simulation.tscn` only |
| `--screenshot` handling | `tools/screenshot_capture.tscn`, instanced by `main_dev.tscn` |
| consts (`MAX_PULL`, `LOOK_SPEED`, ...) | `resources/cue_tuning.tres` |
| `mouse_turns_the_shot`, `fire_now` | deleted; tests emit the real input signals |

## Order of extraction (each step leaves the game running)

1. `CueTuning` Resource with the same values; scripts read from it.
2. `Hud`, `CueStick`, `AimPreview` (pure views).
3. `PoolSimulation` adapter plus `ShotParams` / `ShotOutcome` Resources (the path stays a `PoolShot`).
4. The four input scenes and `CueInput`.
5. `CameraRig`.
6. `ShotPlayback`, `BallRack`, `ShotFlow`.
7. Reduce `game.gd` to the composer and rename it `main`.
