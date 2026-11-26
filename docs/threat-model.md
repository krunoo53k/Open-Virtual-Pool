# Threat model (online protocol doc rev 1, §13)

This is the game-side summary of §13 of the online protocol document (rev `1`,
pinned in [`compat/compat.json`](../compat/compat.json)). It records the v1
trust boundary and the limitations that are **accepted**, not deferred bugs.

## Trust boundary

**The server owns all truth.** The client is an untrusted renderer of
authoritative state and a sender of intent. Nothing computed locally is
promoted to truth:

- no client-derived **outcome**;
- no client-derived **event** list;
- no client-derived **hash**;
- no client-derived **judgement** (rules/foul decisions);
- no client-derived **rack**.

The server resolves the shot, applies the rules, and publishes the result. The
client may predict locally for responsiveness, but prediction is speculative
and always subordinate to the authoritative snapshot.

## Accepted v1 limitations (protocol doc §13)

1. **Local sim as a shot solver.** A modified client can run its exact local
   simulation offline to search for the best shot before sending intent. This
   is accepted for v1: the solver cannot change authoritative state, because
   the server re-resolves the intent itself.
2. **Opponent aim spoofing.** A modified client can draw a false aim for the
   opponent in its own view. This is accepted for v1: it changes only that
   client's presentation, never the server's state or the other client's view.

Both are strictly presentation/intent-side. Neither grants write access to the
authoritative rack, outcome, events, hash, judgement or turn.

## Untrusted snapshot ingestion

The lobby accepts arbitrary server URLs, so any peer/server can supply
snapshots. Before a snapshot is handed to the core it must be validated:

| Check | Rule on failure |
|---|---|
| All numeric values finite (no NaN/Inf) | reject |
| Ball count ≤ 16 | reject |
| Every position on the bed (inside playable extent) | reject |
| Every enum a closed, known value | reject |

**Reject, never clamp.** Clamping an out-of-range value would fabricate a
plausible-looking but non-authoritative rack, which is worse than dropping the
snapshot.

## Integrity response

- **Hash mismatch → snap.** A mismatch between the local prediction hash and
  the authoritative hash discards the predicted frame and snaps to the server
  state; it is not reconciled or averaged.
- **`ERROR` → rollback.** An `ERROR` from the authoritative path rolls back
  speculative local state to the last confirmed frame.

## Out of scope at the pinned rev

At engine rev `2a778c6` there is no engine canary API and no engine-exposed
Rust judge, so client-side canary comparison and server-side judgement are
design commitments rather than deployed checks. See
[`online-multiplayer.md`](online-multiplayer.md) for the stage-2 seam and the
E0 fact-check item (README `1.8` vs loaded model `1.9`).
