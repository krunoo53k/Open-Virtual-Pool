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

# from this repo: boots the menu (the configured main scene)
godot --path . # (editor, 4.7)
```

Headless smoke of the bridge — loads the extension, fires the pinned shot and
checks the golden hash (`c399229b25faae5a`) — exits 0 when it agrees:

```sh
godot --headless --path . scenes/smoke.tscn
```

The `VersionStamp` scene prints and shows `PoolCore.get_model_version` (1.8) on
any running screen, so the loaded extension can be identified while playing.

## Run the menu

`scenes/main_menu/main_menu.tscn` is the configured main scene: plain
`godot --path .` shows a boot splash and then the title screen. It also stands
alone if you want to launch it explicitly:

```sh
godot --path . res://scenes/main_menu/main_menu.tscn
```

- **Play (hotseat 2P)** navigates to `res://scenes/match/match.tscn`. That
  scene arrives with the match-flow work; until it is present the menu prints
  a clear message and stays where it is instead of erroring.
- **Options** opens the display/input panel. *Display mode* picks windowed or
  fullscreen (a no-op in headless runs). The action → key rows rebind the
  InputMap actions declared in `scripts/helpers/input_actions.gd`; **Back**
  returns to the title.
- **Quit** exits with code 0.

Display mode and the key bindings are saved to `user://open_virtual_pool.cfg`
(`[display] fullscreen`, and `[input]` with one label per action). The file is
written on the first change and read again whenever the menu starts.

The two headless acceptance commands both exit 0 when the splash, buttons,
Play target, config round-trip and Quit path hold:

```sh
godot --headless --path . res://tools/main_menu_test.tscn
godot --headless --path . res://tools/menu_quit_test.tscn
```

## Debug: last-shot log

During a match, press **L** to write the last resolved shot to
`user://last_shot.json`. Godot prints the full path to stdout (on Linux:
`~/.local/share/godot/app_userdata/Open Virtual Pool/last_shot.json`). Each
press overwrites the file with the most recent shot.

The snapshot is taken the moment the core resolves the stroke, before the rack
is folded forward to its final frame, so it holds the layout that actually
produced the bug. It is pretty-printed JSON with:

- `model_version` and `player` — which bridge and shooter were live;
- `params` — the exact stroke: speed, aim, elevation, tip offset, called pocket;
- `rack_before` — every ball's number, position and rotation before the shot;
- `shot` — the core's `hash` (the determinism pin) and path duration;
- `outcome` — phase, elapsed time, foul/miscue, pocketed and off-table balls, error;
- `events` — the core's events in order, in ball-number terms.

Paste that file when reporting a bugged shot: the params plus `rack_before`
replay the same core call, and the hash says whether it reproduced. The bind is
checked headlessly with:

```sh
godot --headless --path . res://tools/shot_log_test.tscn
```

## Screenshots

No screenshot assets are committed yet, so none are embedded. Follow-up:
capture the title screen and the options panel, then centre each image with
its caption directly underneath:

```html
<p align="center"><img src="docs/screenshots/title.png" alt="Title screen" width="640"></p>
<p align="center"><em>Title screen — Play, Options, Quit.</em></p>
```

## Art assets

The table cloth and slate (with the six pocket openings cut through), black
pocket throats with thin leather facings, a walnut rail/frame with the long
rails split at the side pockets, the ball sphere and all 21 textures are
generated in Blender from the same geometry numbers `TableLayout` carries.
The pocket openings are also cut through the decorative apron so nothing shows
through the throat. The hole sizes come from the pocket region, not from a
photograph: a corner hole is centred on the drop point with a radius equal to
the 44.45 mm shelf depth, so its near edge is the mouth line and its centre is
the drop line — a ball looks over the hole exactly when it is in the pocket
region, and disappears when the core drops it. Side pockets have a 6.35 mm
shelf, so their jaw-tip half-width at the mouth centre is already honest.
The wooden rails are offset outward from the cushion noses:
originally both boxes shared a top and an inner face, which z-fought along every
rail. The cushions themselves keep the core's exact positions and spans. The source scene
and generator live in `tools/blender/`:

```sh
blender -b --python tools/blender/build_pool_assets.py
godot --headless --path . --import
```

`.blend` source lives under `tools/blender/`, whose `.gdignore` keeps Godot
from trying to import it.
The generated `.obj` meshes, `.png` textures and their `.import` sidecars are
committed, so headless runs need no Blender install. The spec-pinned rail,
cushion, pocket and jaw node names and transforms in `scenes/table/` are
unchanged — only their meshes and materials were replaced.

## Layout

- `project.godot` — Godot 4.7, Forward+; the extension targets api-4.6
  (`compatibility_minimum = 4.6`).
- `bin/pool_godot.gdextension` — the manifest; the built `.so` beside it stays
  gitignored.
- `scenes/main.tscn` — the boot scene: a bare table stand-in plus `VersionStamp`.
- `scenes/smoke.tscn` — the bridge smoke test with the pinned golden hash.
- `.hermes/skills/godot-composition/` — the repo-local composition skill;
  `scripts/lint_composition.py` must stay at zero errors.
