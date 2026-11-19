# 12 — Jets

## Goal

Add a third mode with fast jets and **squadrons**: each side can have several jets that fly in
formation under one player's control. The lobby offers formations like 1 vs 1, 2 vs 2, 3 vs 3 and
the lopsided 1 vs 3 (in the spirit of the original's handicap options). Most of the work is
configuration. If guide 10 went well, the core needs **no changes**.

## Concepts

### Formation flying with one input

Every unit on a side receives the same `Input` (guide 10). If all jets on a side start with the
same direction and speed, applying identical inputs keeps them in **perfect formation**, because
the simulation is deterministic. You don't need to write any formation code.

Things that break formation, all of which are intentional:

- one jet gets hit and spins out, then rejoins the input stream at a different heading
- one-shell-per-*unit* means a squadron of three fires a volley of three shells

### Options as data

Squadron size is a **match option**, not a new mode. `Game.new(Modes.Jet, %{squadron: {2, 2}})`.
That keeps the number of modes small and the lobby flexible. Options flow from:

```
lobby form ─► MatchController ─► Matches.create_match(mode: "jet", opts: %{...})
          ─► GameServer.start_link ─► Game.new(mode, opts) ─► mode.spawn_units(arena, opts)
```

Remember the lesson from guide 10: **validate** options at the edge (the controller). Convert the
form's string `"2v2"` into `{2, 2}` with a whitelist, and never trust raw params further in.

## Steps

### 1. `Combat.Game.Modes.Jet`

`use Combat.Game.Mode`, then implement:

- `name/0` returns `"jet"`.
- `arena/1` returns `Arenas.sky()` (shared with biplanes), or a new arena with fewer, smaller
  clouds. Jets are fast, so they need room.
- `wrap?/0` returns `true`.
- `weapon/0`: fast shells (they must outrun a jet), a short lifetime, quick reload.
- `move_unit/4`: almost the same as Biplane but faster (e.g. speed `[45, 75]`) with a **slower
  turn rate**. Jets are fast but clumsy, which is the whole feel of this mode.
- `spawn_units/2`: read `opts[:squadron]` (default `{1, 1}`). Arrange each side's jets in a small
  **V or line formation** around the spawn point, offset perpendicular to the heading. Every jet on
  a side has the same `dir` and `speed`.

<details><summary>Hint: positions for a formation</summary>

Take the heading vector `h = from_dir(dir)` and a perpendicular `p = {-hy, hx}`. For jet `i` of
`n`, offset it by `p × (i - (n - 1) / 2) × spacing`. That makes a line abreast, centred on the
spawn. For a V, also subtract `h × abs(i - (n - 1) / 2) × spacing`.
</details>

Biplane and Jet now share a lot. Pull common functions (throttle and constant forward motion)
into a `Combat.Game.Flight` helper module that both modes call. Do this *after* Jet works, not
before. Duplication is cheaper than the wrong abstraction, and you only see the right one once
you have two real examples.

### 2. Should a squadron unit be destroyable?

In the tank and biplane modes a hit only spins the victim out. With squadrons you could
**remove** a hit jet for the rest of the round, which makes 1-vs-3 interesting: the lone jet must
pick off the trio. Make it a mode option: `opts[:elimination]`.

- In the core, a hit with elimination enabled **deletes** the unit from `state.units`.
- Add a round-ending rule: if one side has no units, the round ends early and that side loses. Put
  this check in the core, generalised as "a side with no units loses", so every mode gets it.
- Make sure firing, moving and snapshotting all handle a side with zero units without crashing.
  Your tests should cover that.

### 3. Lobby

When `jet` is selected, show a formation select (`1v1`, `2v2`, `3v3`, `1v3`, `3v1`) and an
"elimination" checkbox. Simplest: always render them and ignore them for other modes. Better:
show and hide them with a few lines of JS listening to the mode select's `change` event.

In `MatchController.create/2`, parse these into `%{squadron: {a, b}, elimination: bool}` with
pattern matching on the known strings. Anything unknown falls back to defaults.

### 4. Client

- A `jet` drawer: a sharp arrowhead or delta-wing shape.
- Show remaining units per side in the HUD when elimination is on.

## Tests (`test/combat/game/modes/jet_test.exs`)

- `spawn_units/2` with `{3, 1}` gives three `p1` units and one `p2` unit, all of `p1`'s with the
  same `dir`.
- After 2 seconds of identical turning and throttle input, the three `p1` jets keep the same
  relative offsets to each other (within a small delta). That's formation keeping for free.
- A squadron of 3 holding `fire` produces 3 live shells, never more.
- With elimination on, hitting the only `p2` jet ends the round with `winner: :p1`.
- With elimination off, nothing is ever removed.

## Checkpoint

Play a 1v3 elimination jet match across two windows. Then play a 2v2 without elimination and
watch the formations break up after hits and re-form... or not.

## Stretch goals

- **Split control:** let the player choose which jet in the squadron leads (cycle with a key),
  so only the lead obeys `left`/`right` and the others follow with a small delay. That needs a
  per-unit input history: a ring buffer of the last N inputs per side.
- **Mixed matches:** a biplane vs a jet. What breaks in your abstractions if units on different
  sides use different movement rules?

Next: [13 — Netcode & polish](13-netcode-and-polish.md)
