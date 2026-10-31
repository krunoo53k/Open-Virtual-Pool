# Scene plan template

Fill this in and show it in your reply before creating files.

## Tree

```
Main (composer)
├── ChildA            (scene: scenes/child_a/child_a.tscn)
│   └── PlainNode     (plain node, not a scene)
└── ChildB            (scene: ...)
```

## Table

| Scene | Job (one sentence, no "and") | Children | Needs (typed @export / args) | Emits | Methods others call | Script budget |
|---|---|---|---|---|---|---|
| ChildA | ... | ... | `tuning: CueTuning` | `thing_changed(value: float)` | `show_state(s: State)` | ~40 lines |

## Resources (data contracts)

| class_name | Fields | Used by |
|---|---|---|

## Wiring (done only in the composer)

```
ChildA.thing_changed -> ChildB.set_thing
```

## Checks before coding

- Every scene runs alone (F6 or a demo scene).
- No scene reaches outside its subtree.
- Every cross-scene payload is a typed Resource or a primitive.
- Autoloads: none, or each justified in one line.
