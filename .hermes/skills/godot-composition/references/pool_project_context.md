# Virtual Pool project context

Read this when the repo has `pool-godot/` or `godot-project/`, or the GDScript calls `PoolCore` / `PoolShot`. It records facts that constrain Godot-side code, how the existing API maps onto typed scenes, and a scene plan for the dedicated game with rules.

## Facts that constrain the Godot side

- **The Rust core is the only physics.** One call resolves a shot into a path; Godot samples the path. Balls are never RigidBody nodes.
- **Extension classes:** `PoolCore` (`get_table_geometry()`, `get_table_config()`, `get_model_version()`, `get_miscue_limit()`, `preview_cue_strike(speed, aim, contact)`, `simulate(...)`, `simulate_with_rotations(..., orientations)`) and `PoolShot` (`sample(t)`, `sample_spin(t)`, `sample_rotation(t)`, `get_final_state()`, `get_events()`, `get_ball_state(i)`, `get_hash()`, `get_duration()`, `get_error()`).
- **Coordinate frame** (core right-handed x along, y across, z up; Godot `(x, z, -y)`) is converted in `pool-godot/src/frame.rs`, with the english sign pinned by `tests/mapping.rs`. The `main.gd` you pasted also has its own `_to_godot()` for rack and geometry positions. In the extraction, move that last GDScript conversion behind the `PoolSimulation` adapter (or into Rust) so there is one place.
- **Orientation carry:** each ball's carried rotation is copied from `sample_rotation(duration)` into the next `simulate_with_rotations` call. GDScript never accumulates turns. Keep that in `BallRack`, as plain copies.
- **Determinism pin:** the golden hash `c399229b25faae5a` is pinned in three places (`determinism.rs`, `headless.rs`, `smoke_test.gd`). An extraction that changes the order or values of positions, numbers or rotations given to the core changes the hash, so `smoke_test` is the tripwire.
- **Build and reload:** `./godot-project/build-extension.sh release|debug` builds and copies `libpool_godot.so` (gitignored). A running game keeps the library it loaded: after any Rust `#[func]` change, rebuild and restart. Show `get_model_version()` on the HUD (`VersionStamp`).
- **Godot versions:** editor 4.7 (Forward+); extension built against api-4.6 (`compatibility_minimum = 4.6`).
- **Input today:** there is no `[input]` section in `project.godot`. Everything is hand-rolled in `main.gd`, and tests synthesize events with `parse_input_event`.
- **Conventions to keep:** prose-style lowercase comments and commit messages with § references into `docs/virtual-pool-physics.md`; conventional-commit prefixes; every change ships the test that pins it; rustfmt and clippy clean.

## Determinism at the border (check this in the extraction)

`main.gd`'s `_aim()` builds the cue direction with GDScript `sin`/`cos` (elevation baked into the vector). Those call the platform math library, which the Rust side deliberately avoids with `libm`. A mouse-driven shot is recorded as the final vector, so replays are fine, but shots *computed* by an AI or a test would differ in the last bits across platforms. Preferred fix: expose `make_cue_direction(level_aim, elevation_deg)` from Rust (using `libm`) and call it only from `PoolSimulation`. Until then, never compute directions in GDScript for anything that must reproduce across platforms; store and replay the vector.

## Typed adapter over the existing API

| Raw (core side) | Typed (Godot side), built in `PoolSimulation` |
|---|---|
| `get_table_geometry()` Dictionary, `get_table_config()` JSON | `TableLayout` Resource, built once in `_ready()` |
| `preview_cue_strike(speed, aim, contact)` Dictionary (`velocity`, `elevation_deg`, ...) | `ShotPreview` Resource (ghost, leave direction, elevation, hit ball number) |
| `simulate_with_rotations(speed, aim, contact, positions, numbers, rotations)` | `PoolSimulation.resolve(params: ShotParams, rack: RackState) -> PoolShot`. `PoolShot` is already a typed class; keep it as the path type |
| `PoolShot.get_final_state()`, `get_ball_state(i)`, `get_events()` Dictionaries | `ShotOutcome` Resource: `elapsed_time`, `foul`, `miscue`, `pocketed: Array[int]`, `off_table: Array[int]` |
| contact offset sign (core: + is the shooter's left) | `ShotParams.contact` is in player-intent terms. The adapter and `frame.rs` own the sign. No other scene negates anything |

## Migrating the playground `main.gd` (about 61 KB)

1. **Characterization tests first.** The four headless tests (`smoke_test`, `play_test`, `input_test`, `english_test`) plus the golden hash are the safety net. Run them after every extraction step, however the repo runs them (check the scripts' headers).
2. **Replace test hooks with real entry points.** `fire_now(speed)` becomes a public `take_shot(params: ShotParams)` on the composer: the same entry an AI or a network opponent uses, so it is a feature rather than a hook. `mouse_turns_the_shot` goes away; tests send events to the scene under test.
3. **Input actions.** Because editing `[input]` in `project.godot` by hand is error-prone, register defaults in one `InputActions.register_defaults()` static helper called from the composer's `_ready()` (see `tscn_cheatsheet.md`): `cue_draw` (S), `cue_raise` (B), `english_hold` (E), `fine_trim` (F), `debug_toggle` (D), `camera_toggle` (C), `cancel` (Esc). Tests send `InputEventAction` plus mouse motion.
4. **Keep as dev-only scenes:** screenshot capture (`shot.tscn` and its camera args), `aim_probe`, `ghost_probe`. Gameplay scenes never parse the command line.
5. **Extraction order:** `CueTuning` Resource (same values) -> views (`Hud`, `CueStick`, `AimPreview`) -> `PoolSimulation` adapter plus typed Resources -> input scenes -> `CameraRig` -> `ShotPlayback`, `BallRack`, `ShotFlow` -> reduce `main.gd` to a composer. No behaviour changes in these steps.

## Scene plan for the dedicated game (rules, opponent, match flow)

```
Match (match.tscn, composer)
├── Table, BallRack, PoolSimulation, ShotPlayback, CueStick, AimPreview, CameraRig, Hud   (from the extraction)
├── HumanShooter          cue_input.tscn      emits shot_committed(params: ShotParams)
├── AiShooter             ai_shooter.tscn     emits shot_committed(params: ShotParams)   (later)
├── BallInHandInput       ball_in_hand_input.tscn   emits cue_ball_placed(position: Vector3)
├── EightBallRules        rules node (pure logic)   judge(outcome, match_state) -> Judgement
└── TurnFlow              state nodes: AwaitingShot, Striking, Rolling, Judging, BallInHand, GameOver
```

- **Interchangeable producers.** `HumanShooter` and `AiShooter` both emit `ShotParams`. `TurnFlow.activate(player)` tells the composer which one to listen to. Nothing else cares who is shooting.
- **`Judgement` Resource:** `foul_reason`, `next_player`, `ball_in_hand`, `groups_assigned`, `game_over`, `winner`.
- **`MatchState` Resource:** current turn, group assignment, ball-in-hand flag, scores. Passed in and returned, never stored in a global.
- **Signals out of the rules node:** `turn_changed(player: int)`, `foul_committed(reason: int)`, `ball_in_hand_granted(player: int)`, `groups_assigned(solids_player: int)`, `game_over(winner: int)`. The HUD and `TurnFlow` react; the rules node knows no scenes.

## Decisions confirmed by kruno (2026-10-31, for the Open-Virtual-Pool game repo)

1. **Rules:** GDScript `EightBallRules` node in the game repo, headless-tested with JSON fixtures in that repo. The Rust port is a kanban backlog card (#11) before netcode work, not done up front.
2. **Bootstrap:** fresh scenes in the new repo; it consumes the engine repo's `pool-godot` build (`../Virtual-Pool-Physics-Engine/godot-project/build-extension.sh`); the 61 KB playground `main.gd` is reference only, never ported.
3. **Ruleset:** strict BCA — called pocket on the 8 (wrong/uncalled 8 = loss), ball-in-hand anywhere on the table, 8-on-break re-rack, >=4 object balls driven to a rail for a legal break.
4. **Kanban:** the game repo is **GitHub** (`git@github.com:krunoo53k/Open-Virtual-Pool`, gh CLI authed) — NOT Forgejo; column labels `backlog/todo/in-progress/done`, protocol in the label descriptions; cards are issues #1-#11, deps always lower-numbered; one branch `feat/NN-slug` + one PR per card; PR body ends `Closes #NN`.
