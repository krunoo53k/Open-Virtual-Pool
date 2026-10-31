# Open Virtual Pool

A deterministic 8-ball pool game on the virtual pool physics core. The Rust
core in [`Virtual-Pool-Physics-Engine`](https://github.com/krunoo53k/Virtual-Pool-Physics-Engine)
is the only physics: one call resolves a shot into a path; Godot samples the
path and draws it. GDScript never simulates.

## Dev run

The game consumes the engine repo's `pool-godot` build. Nothing in this repo
holds a compiled library; `bin/*.so` is gitignored.

```sh
# from the sibling engine repo
cd ../Virtual-Pool-Physics-Engine
./godot-project/build-extension.sh release
cp godot-project/bin/libpool_godot.so ../Open-Virtual-Pool/bin/

# from this repo: open the main scene
godot --path . # (editor, 4.7)
```

Headless smoke of the bridge — loads the extension, fires the pinned shot and
checks the golden hash (`c399229b25faae5a`) — exits 0 when it agrees:

```sh
godot --headless --path . scenes/smoke.tscn
```

The `VersionStamp` scene prints and shows `PoolCore.get_model_version` (1.8) on
any running screen, so the loaded extension can be identified while playing.

## Layout

- `project.godot` — Godot 4.7, Forward+; the extension targets api-4.6
  (`compatibility_minimum = 4.6`).
- `bin/pool_godot.gdextension` — the manifest; the built `.so` beside it stays
  gitignored.
- `scenes/main.tscn` — the boot scene: a bare table stand-in plus `VersionStamp`.
- `scenes/smoke.tscn` — the bridge smoke test with the pinned golden hash.
- `.hermes/skills/godot-composition/` — the repo-local composition skill;
  `scripts/lint_composition.py` must stay at zero errors.
