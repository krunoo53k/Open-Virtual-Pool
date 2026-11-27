# Online multiplayer — v1 status

This is the game-side record of the online work. It describes what exists at the
pinned revisions in [`compat/compat.json`](../compat/compat.json), not a shipped
online mode. v1 is server-authoritative with a thin, untrusted client.

## Pinned revisions and what is actually present

| Manifest key | Value | Meaning |
|---|---|---|
| `core` | `145dd3f2f2e33894afedcbcac05a3ca78e6ae2c0` | Engine merge commit of PR #7 (`feat/online-multiplayer-engine`). |
| `rules` | `860b664886536e742ccb0a07a2823d9bc13a78ab` | Shared `pool-rules` revision. |
| `intent` | `860b664886536e742ccb0a07a2823d9bc13a78ab` | Shared `pool-intent` revision. |
| `protocol` | `1.0` | Online protocol doc revision; §13 is the threat model. |
| `model` | `1.10` | Model version reported by the loaded engine. |
| `canary` | `c8ee370c4195017f` | Engine-published three-shot canary sent in HELLO. |

At this revision the engine ships `simulate_from_intent_f64`,
`preview_shot_json` / `judge_json`, `pool-intent`, `pool-rules` and an 81-shot
corpus. The client uses all of them; the f32 hotseat bridge remains for the
hotseat sunset window.

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

## C1 client work: both stages landed

- **Stage 1.** `RackState` holds positions and rotations as flat **core-frame
  f64 triples** (`x` along the table, `y` across, `z` up), with one-way display
  accessors. This is the wire layout too, so a rack crosses the socket without
  a Vector3 pack or an f32 round trip.
- **Stage 2.** `PoolSimulation.USE_F64_INTENT` is `true`. Online shots call the
  engine's `simulate_from_intent_f64` with flat core-frame arrays, so no number
  loses precision at the GDExtension boundary; hotseat still calls the legacy
  f32 bridge through `resolve()`.
- **Hotseat sunset.** The f32 path has a provisional date of **2027-06-30**.
  Parity with the Rust judge is already pinned by
  `tools/judge_parity_test.tscn` (54 fixtures); retiring the GDScript judge for
  hotseat is a separate cleanup step before that date.
- **Ruling preview.** The composer calls the engine's shared Rust judge via
  `preview_shot_json`; the result is display-only and COMMIT always wins.

## Platform matrix

| Target | Status | Basis |
|---|---|---|
| Desktop Linux / Windows / macOS | **supported** | Full extension, both hotseat f32 and online f64 paths; the 81-shot corpus runs on x86_64. |
| Mobile Android / iOS | **corpus verified on aarch64, native playback pending** | The corpus replayed under `qemu-aarch64-static`; no on-device gdext build has been shipped. |
| Web browser | **out of scope for v1** | gdext-web requires an experimental Emscripten build; the v2 direction is a standalone wasm module of `pool-core`/`pool-intent`/`pool-rules`. |

The engine's E0 spike also ran the pure-Rust crates and the corpus under
wasm32-wasip1 as a determinism lane. That is not browser playback.

## Serialization caveat and the base64 fallback

Godot 4.7's `JSON.parse_string` shifts some arbitrary 17-significant-digit f64
values by one ULP and underflows subnormals, even though
`JSON.stringify(..., full_precision=true)` prints them correctly. The engine
side reads the same text with a correctly-rounding JSON reader, so the two can
disagree. `ProtocolCodec` implements the protocol §4 fallback:
`rack_to_wire()` / `wire_to_rack()` carry the flat arrays as base64
little-endian f64 bytes, and `tools/f64_bit_pattern_test.tscn` pins 601
arbitrary bit patterns through a full frame. The online pipeline must agree
with the server to use that form before launch; the plain form remains the
fixture shape until then. Prediction always runs on the values that came back
from the wire, never on the caller's locals.

## E0 fact check — resolved

The `VersionStamp` paragraph in the README said `1.8`; the engine source and
loaded extension now report **`1.10`**, and the README has been corrected.
The pinned manifest records that value together with the engine's published
canary.

## CI and further reading

`.github/workflows/ci.yml` checks `compat/compat.json`, builds the engine at the
pinned commit, imports the project (a fresh checkout has no `.godot/` caches),
copies the binary into `bin/`, and runs every headless harness. One input
harness (`tools/input_scene_test.tscn`) is known-failing at baseline and is
isolated with `continue-on-error` (see the README). Trust details live in
[`threat-model.md`](threat-model.md).
