# Online multiplayer — v1 status

This is the game-side record of the online work. It describes what exists at the
pinned revisions in [`compat/compat.json`](../compat/compat.json), not a shipped
online mode. v1 is server-authoritative with a thin, untrusted client.

## Pinned revisions and what is actually present

| Manifest key | Value | Meaning |
|---|---|---|
| `core` | `2a778c6` | Engine revision, branch `fix/clippy-warnings`. |
| `rules` | `null` | No pinned rules crate revision yet — pending. |
| `intent` | `null` | No pinned intent crate revision yet — pending. |
| `protocol` | `1` | Online protocol doc revision; §13 is the threat model. |
| `model` | `1.9` | Model version reported by the loaded engine, not the stale README line. |

At engine rev `2a778c6` there is **no** `simulate_from_intent_f64`, **no** engine
canary API, **no** engine-exposed Rust judge, and **no** `pool-intent` /
`pool-rules` crates. The client must not call entry points that are not there;
the seams below are written against their future arrival.

## Authority and data flow

The server owns all truth: rack, turn, outcome, events, hashes, and judgement.
The client sends **intent** only. In the lobby the player may enter an arbitrary
server URL, so every server snapshot is treated as untrusted input before it is
handed to the core:

- validate that all numbers are **finite** (reject NaN/Inf);
- accept **at most 16 balls**;
- require every position to be **on the bed** (inside the playable table
  extent), never off-table or below it;
- require every enum to be a **closed, known value**.

Invalid snapshots are **rejected, never clamped** — clamping would silently
change the authoritative picture. No client-derived outcome, event, hash,
judgement or rack is trusted. A hash mismatch **snaps** to the authoritative
state; an `ERROR` **rolls back** any speculative local state. See
[`threat-model.md`](threat-model.md) for the accepted limitations (local solving
and aim spoofing).

## C1 client work: stage 1 landed, stage 2 pending

- **Stage 1 (landed).** `RackState` holds positions and rotations as flat
  **core-frame f64 triples** (`x` along the table, `y` across, `z` up), with a
  legacy **f32 bridge** for the existing `take_shot` path. This is the same
  layout the wire uses, so a rack can cross the socket without a Vector3 pack
  or an f32 round trip.
- **Stage 2 (pending).** `PoolSimulation.USE_F64_INTENT` is the switch. It is
  currently `false`; the branch that calls `simulate_from_intent_f64` is written
  but cannot be flipped until the engine entry point lands at the pinned rev.
- **Hotseat** stays on the legacy f32 path. Provisional sunset date for that
  path: **2027-06-30** (six months from 2026-11-26). The date is provisional —
  it holds only once the engine f64 intent entry point exists and the harnesses
  pin parity.

## Platform matrix

| Target | Status | Basis |
|---|---|---|
| Desktop Linux / Windows / macOS | **supported** | These are the only targets with a shipped extension binary manifest (`bin/pool_godot.gdextension`). The extension targets API 4.6, Godot 4.7 headless harnesses run on Linux. |
| Mobile Android / iOS | **pending G0 spike** | No on-device extension build has been verified; no shipped binary manifest. |
| Web browser (wasm / gdext) | **pending G0 spike** | No gdext/web wasm spike result exists on disk. Browser prediction is not asserted. |

Web flips to **supported** only when all three hold:

1. the GDExtension **loads in the browser**;
2. the engine **canary matches** the server's value;
3. **prediction runs** locally and agrees with the pinned hashes.

Until then web play must use the server-authoritative remote path (snapshots
from `COMMIT`, no local prediction). Revisit the matrix when a gdext/web spike
produces a reproducible result, not before.

## Serialization caveat and the base64 fallback

Godot 4.7's `JSON.parse_string` shifts some arbitrary 17-significant-digit f64
values by one ULP and underflows subnormals, even though
`JSON.stringify(..., full_precision=true)` prints them correctly. The plain
array form in the golden fixtures therefore cannot be a bit-exact pin on this
target. `ProtocolCodec` implements the protocol §4 fallback:
`rack_to_wire()` / `wire_to_rack()` carry the flat arrays as base64
little-endian f64 bytes, and `tools/f64_bit_pattern_test.tscn` pins 601
arbitrary bit patterns through a full frame. The online pipeline must agree
with the server to use that form before launch; the plain form remains the
fixture shape until then. Prediction always runs on the values that came back
from the wire, never on the caller's locals.

## E0 fact-check items

- The `VersionStamp` paragraph in the README still says `get_model_version()`
  is `1.8`; the loaded engine reports **`1.9`**. That old line is deliberately
  left unchanged here and must be corrected by the E0 fact-check task, not
  silently rewritten. The pinned manifest records the loaded value (`model:
  1.9`).

## CI and further reading

`.github/workflows/ci.yml` checks `compat/compat.json`, builds the engine
extension at rev `2a778c6`, copies the binary into `bin/`, and runs every
headless harness. Two input harnesses are known-failing at baseline and are
isolated with `continue-on-error` (see the README). Trust details live in
[`threat-model.md`](threat-model.md).
