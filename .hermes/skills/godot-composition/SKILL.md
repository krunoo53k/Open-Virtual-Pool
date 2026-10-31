---
name: godot-composition
description: Build Godot 4 projects the Godot way - many small single-purpose scenes composed through signals and typed exports, instead of one big script that builds nodes with .new(), polls input, runs a state machine, draws the HUD and plays back results. Use this skill whenever a task touches a Godot project - creating or editing .tscn scenes, .gd GDScript, node trees, signals, input handling, cameras, HUD/UI, GDExtension or Rust bridges - or the user mentions Godot, scenes, nodes, GDScript, composition, or refactoring a game script. Use it even for a small change, and always before writing any script over ~50 lines or any code that calls add_child() or .new() on nodes.
---

# Godot composition

Godot's unit of design is the **scene**: a small tree of nodes with one job, instanced inside bigger scenes. Left alone, agents drift to the opposite: one large script that builds every node in `_ready()`, handles raw keys, runs a phase enum, formats HUD text and plays back results. It runs, but it cannot be opened in the editor, reused, tested alone, or changed without touching everything. This skill keeps work in small scenes that are wired together.

## The five habits

1. **Plan the tree before writing files.** State the scene tree and a table of each scene's responsibility, exports, signals and methods (template: `references/scene_plan_template.md`). No plan, no files.
2. **One scene, one job.** If describing a scene needs "and", split it. Names ending in Manager, Controller, Handler or System usually hide two jobs.
3. **Structure lives in `.tscn`, not in `_ready()`.** Static node trees are scene files you can see in the editor. Code may instantiate a *PackedScene* many times (16 balls); it should not assemble meshes, lights and labels with `.new()`.
4. **A scene knows only its own subtree.** Dependencies come in as typed `@export` values or method arguments; events go out as signals. Only the scene that *instances* the children wires them together.
5. **Data crosses scene borders as typed Resources** (`class_name ShotParams extends Resource`), not Dictionaries or loose argument lists.

## Workflow

1. **Inventory (existing project).** Run `python scripts/lint_composition.py <project_dir>` first to get a baseline. List existing scenes with `find <project_dir> -name "*.tscn"`.
2. **Plan.** Write the scene plan in your reply. If you will create more than ~6 scenes and the user is present, pause for a yes; otherwise continue and let them redirect.
3. **Build leaves first.** For each leaf scene: the `.tscn`, a small script on its root if it needs behaviour, and a way to run it alone (F6 or a `*_demo.tscn`). Leaves never reference the scene that will contain them.
4. **Compose.** The parent scene instances the children and connects signals, in the `.tscn` (`[connection ...]`) when static, or in `_ready()` when dynamic. The composer's script stays short; it wires and routes, it does not compute.
5. **Check.** Run the lint again and fix every ERROR. Explain or fix every WARNING. If a Godot binary is available, load the project headless (see `references/tscn_cheatsheet.md`).
6. **Report** with the tree, the signal table, and the lint summary.

## Is it a node, a scene, or a variable?

- **Its own scene** if it has its own input, visuals or lifecycle, you would run it alone, or you might swap or reuse it. (`StrengthInput`, `CueStick`, `CameraRig`.)
- **A plain child node** if it is just structure inside one scene. (The line, ghost and marker meshes inside `AimPreview`.)
- **A variable, Resource field or function** if it is only a value or a calculation. (`cue_angle` is a float inside `ElevationInput`; it does not need a node.)

## How scenes talk

| From → to | Use |
|---|---|
| Parent → child | Call the child's method or set its `@export`. |
| Child → parent | Emit a signal. The child never calls `get_parent()`. |
| Sibling ↔ sibling | The composer connects `A.signal → B.method`. |
| Shared data | A typed Resource passed in by the composer. |
| Truly global service | An autoload, with a one-line justification in the plan. Default is none. |

Signal names are past-tense events (`shot_committed`, `stroke_released`), typed, three parameters at most; use a Resource payload beyond that.

## Hard rules (the lint checks these)

- No `get_parent()`, `../` paths, `/root/...`, `get_tree().root` or `current_scene`. (`no-parent-reach`, `no-tree-reach`)
- Script budgets: ≤100 code lines, ≤8 public vars, ≤12 functions, ≤40 lines per function. Over budget means split. (`script-too-long`, `too-many-vars`, `too-many-funcs`, `long-func`)
- No more than 2 `Node.new()`-style constructions in a script; build scenes instead. (`nodes-built-in-code`)
- Input goes through InputMap actions (`Input.is_action_pressed("fine_trim")`), never `KEY_*` constants or `InputEventKey`. One input scene per concern, and it emits *intent* signals without knowing who listens. If you cannot use the editor, register the actions in one `InputActions.register_defaults()` helper (see cheatsheet). (`use-input-map`)
- Signals carry typed parameters, no bare `Dictionary` or `Array`. (`signal-untyped`)
- Tuning numbers are `@export` values or a Resource, not a wall of `const`s. Physical constants with a source are fine. (`too-many-consts`)
- Views (HUD, cue model, preview, debug panel) only display what they are given. They do not call the physics or decide rules.
- One adapter node wraps each external engine (e.g. a Rust GDExtension): it owns the typed API and any coordinate-frame conversion. Nothing else touches the raw object. (`wrap-extension`: a human check, no automated rule)
- No test hooks in production scripts (`fire_now()`, `mouse_turns_the_shot`). Tests drive the real inputs and signals. If a test needs a way to act directly, expose the same public method an AI or network player would use (e.g. `take_shot(params)`). Dev tools (screenshot capture, debug overlay) are separate scenes added by a dev-only composer such as `main_dev.tscn`. (`test-hook`, `cli-in-game-script`)
- Do not `preload("res://x.gd")` to dodge `class_name`. Run the project import so the class cache exists (see cheatsheet). (`preload-script`)
- At most one autoload without justification. (`autoloads`)

A justified exception is allowed with a comment on the same or previous line: `# lint-ignore: rule-id (reason)`.

## When the code already exists (god-script refactor)

Do not rewrite in one pass, and do not change behaviour while restructuring.

1. **Find the existing tests and keep them green after every step.** They are the characterization suite. If tests reach into the script's internals, migrate them to the real inputs, signals or public composer API in the same step. If there are no tests, write one that pins current behaviour before extracting.
2. Read the script and group its vars and functions by responsibility. Show the extraction map (which chunk goes to which scene).
3. Extract in order of lowest coupling: pure views, then input, then camera, then playback, and the composer last.
4. After each extraction: the game still runs, moved code is deleted from the old script (no duplicates), the lint count goes down.
5. Move tunable constants into a Resource with the **same values**. Keep numbers and control feel identical.
6. Features, bug fixes and "improvements" wait for a separate change.

A worked example mapping a real 1000-line game script onto scenes is in `references/worked_example_pool.md`.

## References

- `references/scene_plan_template.md`: the plan table to fill in before coding.
- `references/antipatterns.md`: smells, why they hurt, the fix. Skim when unsure.
- `references/worked_example_pool.md`: pool-game scene tree, signal map and extraction map.
- `references/pool_project_context.md`: **read when the repo has `pool-godot/` or uses `PoolCore`.** Real API mapping, test and hash-pin safety net, migration steps, and the scene plan for rules, AI and match flow.
- `references/tscn_cheatsheet.md`: hand-writing `.tscn`, wiring signals, headless checks, class cache.

## Report template

```
Scene tree: <indented tree>
Signals: <Emitter.signal(args) -> Receiver.method>
Resources: <class_name list>
Lint: <errors/warnings before -> after>
Not done / assumptions: <anything left>
```
