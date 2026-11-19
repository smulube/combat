# 08 — Canvas client

## Goal

Two browser windows join the same match, each player drives their own tank with the keyboard,
and both screens show the same battle. **This is the first time it's a game.**

## Concepts

### Thin client

The client has three jobs and no game rules:

1. **Send** what keys are held.
2. **Store** the most recent snapshot.
3. **Draw** it as often as the screen refreshes.

If you catch yourself writing collision code in JS, stop. That belongs to the server.

### Two loops running at different rates

- **Network:** snapshots arrive ~30×/second, whenever the server sends them.
- **Rendering:** `requestAnimationFrame(callback)` calls you once per display refresh (60, 120 or
  144 Hz) and pauses when the tab is hidden.

They're decoupled. The render loop just draws "whatever the latest snapshot is". This guide shows
movement updating at 30 Hz, which looks slightly steppy on a 120 Hz screen. Guide 13 smooths it
with interpolation.

### Send state changes, not keypresses

Send the **whole input state** (`{left, right, forward, back, fire}`), and only **when it
changes**. This is robust: if a message is ever lost or reordered, the next one fully corrects
things. The server's `Input.from_params/1` already expects exactly this shape.

### Keyboard gotchas

- Use `event.code` (`"ArrowLeft"`, `"KeyA"`, `"Space"`) rather than `event.key`. `code` is the
  physical key, so it works regardless of keyboard layout.
- Holding a key fires repeated `keydown` events (`event.repeat === true`). Your "only on change"
  diff already ignores them.
- Call `preventDefault()` for arrows and space, or the page scrolls.
- If the window loses focus while a key is held, you'll never get its `keyup`, and the tank
  drives forever. Listen for `blur` and reset everything to `false`.

## Steps

Organise the client as small ES modules in `assets/js/game/`.

### 1. `net.js`: connecting

Export `connect({ matchId, token, onJoin, onSnapshot, onError })`, which returns the channel.

```js
import { Socket } from "phoenix"
```

- Create `new Socket("/socket", { params: { token } })` and call `.connect()`.
- `socket.channel(\`game:${matchId}\`, {})`.
- `channel.on("snapshot", onSnapshot)`.
- `channel.join()` with `.receive("ok", onJoin)` and `.receive("error", onError)`.

The token comes from `document.querySelector("meta[name='player-token']").content`.

Read the Phoenix JS client docs (https://hexdocs.pm/phoenix/js/) for `Socket` and `Channel`,
especially what happens on reconnect: **the client rejoins automatically.** Because your server
`join` is idempotent by player id, a rejoin gets the same slot. That design decision just paid off.

### 2. `input.js`: the keyboard

Export `createInput(onChange)`:

- Keep a `state` object `{ left, right, forward, back, fire }`, all false.
- A key map, e.g. `ArrowLeft`/`KeyA` → `left`, `ArrowUp`/`KeyW` → `forward`,
  `Space`/`KeyF` → `fire`.
- On `keydown`/`keyup`, look up the action and ignore unmapped keys. If the value changed, update
  `state` and call `onChange({...state})`.
- On `window` `blur`, reset everything and call `onChange` once.
- Return a `destroy()` that removes the listeners. It's good hygiene, and useful in guide 09.

In `index.js`, wire `onChange` to `channel.push("input", state)`.

### 3. `renderer.js`: drawing

Export `createRenderer(canvas)`, returning `{ setArena(arena), draw(snapshot, mySlot) }`.

- `ctx.imageSmoothingEnabled = false`.
- **Arena:** fill the background, then `fillRect` each wall. Walls never change, so a nice
  optimisation is to draw them once onto an **offscreen canvas** in `setArena` and then
  `drawImage` it each frame.
- **Tanks:** for each tank in `snapshot.tanks`:
  - `ctx.save()`, `ctx.translate(x, y)`, `ctx.rotate(dir * Math.PI / 8)`, draw a blocky tank
    pointing along **+x** (a 6×6 body plus a 4×2 barrel sticking out to the right), then
    `ctx.restore()`
  - the direction convention matches the server (0 = east, clockwise, because canvas `y` points
    down), so it lines up for free
  - give each slot its own colour, and while `spinning` is true make the tank flash (alternate
    colours based on `performance.now()`)
- **Shells:** `fillRect(x - 0.5, y - 0.5, 1.5, 1.5)` in the owner's colour, if you add `owner`
  to the shell snapshot (a good small server change to make now).
- **Your tank:** make it clear which one is yours, e.g. a small marker above it, or an outline.

<details><summary>Hint: snapping rotated shapes for a chunkier look</summary>

At 160×100, rotated rectangles get anti-aliased into blurry blobs. Two options: (a) accept it,
since it reads fine; or (b) pre-draw 16 tiny sprites, one per direction, as pixel grids
(arrays of strings like `"..##.."`), and `drawImage` the right one. Option (b) is the authentic
look. It's a lovely evening project once everything else works.
</details>

### 4. HUD in the DOM

Text drawn at 160×100 looks terrible. Put the HUD in HTML instead. In `show.html.heex`, add
elements for each score, the timer and a status line, and update their `textContent` when a
snapshot arrives (not every frame). Format the timer as `m:ss`. Show who won when
`status === "over"`.

### 5. `index.js`: tying it together

`startGame()`:

1. Find the canvas and read `data-match-id`.
2. `connect(...)`. On join, store `mySlot`, call `renderer.setArena(resp.arena)`, and create the
   input.
3. On snapshot, store it as `latest` and update the HUD.
4. Start the `requestAnimationFrame` loop that calls `renderer.draw(latest, mySlot)` when
   `latest` exists.
5. Temporarily add a "Start" button that does `channel.push("start", {})` (this matches the
   temporary `handle_in` from guide 07).

## Checkpoint: play!

1. `iex -S mix phx.server`.
2. Window A: open http://localhost:4000/play/TEST.
3. Window B: open the **same URL in a private/incognito window**. It needs a different session
   cookie and so a different player id. Two normal tabs share a session, so they would both be
   `p1`.
4. Press Start, then drive and shoot. Both windows should agree on everything.

Debugging tips:

- In the browser devtools **Network → WS** tab, click the socket and watch the frames go back
  and forth. You can see the exact JSON of every snapshot.
- In iex, `:sys.get_state(Combat.Matches.whereis("TEST"))` shows the authoritative state.
- Simulate lag with Chrome devtools network throttling (it applies to WebSockets in recent
  versions) and feel why guide 13 exists.

## Stretch goals

- Draw a muzzle flash for a frame or two on `fire` events, and an explosion on `hit` events.
- Draw the remaining time as a bar along the bottom edge of the canvas.
- Gamepad support via the Gamepad API (poll it in the render loop, and feed the same `onChange`).

Next: [09 — Lobby & matchmaking](09-lobby-and-matchmaking.md)
