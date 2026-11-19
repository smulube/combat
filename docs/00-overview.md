# 00 — Overview & architecture

## What we're building

A browser game where two people, each on their own computer, fight each other in real time.
It has three families of game mode, loosely following the original *Combat* cartridge:

1. **Tank:** top-down tanks in a walled arena. Shells travel in straight lines, and a hit tank
   spins out and the shooter scores a point.
2. **Biplane:** planes that never stop moving, wrap around the screen edges, and can hide in clouds.
3. **Jet:** faster planes, optionally in squadrons of several jets per side.

A round lasts **2 minutes 16 seconds** (the original's round length). The higher score wins.

> **On originality:** we copy *mechanics*, never assets. Draw your own blocky shapes and pick
> your own colours and sounds.

## How to use these guides

Every guide has the same sections:

- **Goal:** what works at the end.
- **Concepts:** the OTP/Phoenix ideas you need, explained before you use them.
- **Steps:** what to create, with file paths, module names, function signatures, data shapes
  and the behaviour each function needs. Full implementations are left out on purpose.
- **Hints:** collapsed `<details>` blocks. Try without them first.
- **Checkpoint:** how to prove it works (a test, an `iex` session or the browser).
- **Stretch goals:** optional extras.

When a guide gives a function signature like `tick(state, dt) :: State.t()`, writing the body is
your job. When a guide shows a complete snippet, it's because the snippet teaches an API rather
than game logic.

## Architecture in one picture

```
 Browser A                                   Browser B
 ┌──────────────────────┐                    ┌──────────────────────┐
 │ keyboard ─► input.js │                    │ keyboard ─► input.js │
 │ canvas  ◄─ renderer  │                    │ canvas  ◄─ renderer  │
 └────────┬─────────▲───┘                    └────────┬─────────▲───┘
   "input"│         │"snapshot"               "input" │         │ "snapshot"
          ▼         │      WebSocket                  ▼         │
 ┌──────────────────┴──────────────── Phoenix ────────────────────┴─────┐
 │  GameChannel (one process per connected browser)                     │
 │        │ Combat.GameServer.set_input/3          ▲ {:snapshot, map}   │
 │        ▼                                        │ via Phoenix.PubSub │
 │  Combat.GameServer (one GenServer per match) ───┘                    │
 │        │ calls pure functions every tick                             │
 │        ▼                                                             │
 │  Combat.Game  (pure functional core: no processes, fully testable)   │
 └──────────────────────────────────────────────────────────────────────┘
```

**The server is authoritative.** Browsers only say "these keys are held down". The server
runs the simulation and tells everyone what happened. A client can't cheat by claiming it
hit someone, and the two players can never disagree about the state of the game.

**Functional core, imperative shell.** All the game rules live in plain modules
(`Combat.Game.*`) that take data and return data. The processes (GenServer, channels) are a
thin shell that holds state and moves messages around. This is why guides 02–04 contain no
processes at all: you can build and test the whole game in `mix test` before any networking
exists.

## The process tree (by guide 09)

```
Combat.Supervisor (one_for_one)
├── CombatWeb.Telemetry
├── {Phoenix.PubSub, name: Combat.PubSub}
├── {Registry, keys: :unique, name: Combat.MatchRegistry}      ← guide 06
├── {DynamicSupervisor, name: Combat.MatchSupervisor}          ← guide 06
│     ├── Combat.GameServer  (match "QXKB")
│     └── Combat.GameServer  (match "MZPA")
├── CombatWeb.Presence                                         ← guide 09
└── CombatWeb.Endpoint
      └── (one GameChannel process per connected player)
```

## What happens in one tick

1. The `GameServer` receives its `:tick` message, about 30 times per second.
2. It calls `Combat.Game.tick(state, dt)`, a pure function that moves things, resolves
   collisions and updates scores and the timer.
3. It calls `Combat.Game.snapshot(state)` to build a small JSON-friendly map.
4. It broadcasts `{:snapshot, snapshot}` on the PubSub topic `"match:<id>"`.
5. Each `GameChannel` subscribed to that topic pushes the snapshot down its WebSocket.
6. Each browser stores the snapshot, and its `requestAnimationFrame` loop draws it.

Input travels the other way. A key press in the browser sends a channel message `"input"`.
The `GameChannel` calls `Combat.GameServer.set_input/3`, the server stores it, and the next tick
uses it.

## Naming conventions (used in every guide)

| Thing | Name |
|-------|------|
| OTP app / top namespace | `:combat` / `Combat` |
| Pure game core entry point | `Combat.Game` |
| Core structs | `Combat.Game.State`, `.Tank` (renamed `.Unit` in guide 10), `.Shell`, `.Arena`, `.Input` |
| Vector helpers | `Combat.Game.Vec` |
| Collision helpers | `Combat.Game.Collision` |
| Arena layouts | `Combat.Game.Arenas` |
| Match process | `Combat.GameServer` |
| Match registry / supervisor | `Combat.MatchRegistry` / `Combat.MatchSupervisor` |
| Public match API | `Combat.Matches` |
| Socket / channel | `CombatWeb.UserSocket` / `CombatWeb.GameChannel` |
| Channel topic | `"game:<match_id>"` |
| PubSub topic (server → channels) | `"match:<match_id>"` |
| Player slots | `:p1` and `:p2` (atoms on the server, `"p1"`/`"p2"` in JSON) |
| Match id | 4 uppercase letters, e.g. `"QXKB"` |
| Game modes (guide 10+) | behaviour `Combat.Game.Mode`; `Combat.Game.Modes.Tank`, `.Biplane`, `.Jet` |

## Units and coordinates

- The **world is 160 × 100 logical units**. The browser scales it up to fit the screen, so the
  server never thinks in pixels.
- The origin `(0, 0)` is the **top-left** corner. `x` grows to the right and `y` grows *downwards*,
  which matches canvas.
- **Time** is in seconds as floats inside the core (`dt = 0.033`). Speeds are in units per second.
- **Directions** come in 16 steps (`0..15`), just like the original hardware. Guide 02 explains this.

## Glossary

- **Tick:** one step of the simulation.
- **Snapshot:** the subset of state sent to clients after a tick.
- **Slot:** which side a player controls (`:p1` or `:p2`).
- **Mode:** a module that supplies the rules that differ between Tank, Biplane and Jet.
- **AABB:** axis-aligned bounding box, a rectangle that isn't rotated. It's the cheapest shape to
  collide.

Next: [01 — Project setup](01-project-setup.md)
