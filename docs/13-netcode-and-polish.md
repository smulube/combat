# 13 — Netcode & polish

## Goal

The game feels smooth even at 30 Hz and with real-world latency. It copes with players
disconnecting and coming back. Empty matches clean themselves up, and the game makes retro
noises.

This guide is a set of mostly independent sections, so do them in any order.

## Part A: Snapshot interpolation

### Concept

Snapshots arrive every ~33 ms, but with **jitter**: sometimes 20 ms apart, sometimes 50. Drawing
the latest one makes motion stutter. The standard fix, used in many shipped games, is to:

1. Buffer the last few snapshots, each with the time it arrived.
2. Render the world as it was a fixed **interpolation delay** ago, say 100 ms.
3. Find the two buffered snapshots either side of that moment, and **linearly interpolate**
   each unit's position between them.

You trade ~100 ms of extra visual latency for perfectly smooth motion. Your own inputs still
travel to the server instantly. Only what you *see* is delayed.

```
snapshots:   S1 ───────── S2 ───────── S3 ───────── S4 (latest)
render time:                   ▲ (now - 100ms)
                     draw lerp(S2, S3, t)
```

### Steps

- **Server:** add a `tick` counter to the `GameServer` (incremented per tick) and include it in
  every snapshot. This allows ordering and lets you spot dropped snapshots.
- **Client:** create `assets/js/game/interpolation.js`:
  - `push(snapshot)` stores `{ at: performance.now(), snap }` in a buffer of the last ~10
    entries
  - `sample(renderTime)` finds the bracketing pair and returns an interpolated snapshot:
    - **units** are matched **by id** between the two snapshots. A unit present in only one of
      them (it just appeared, was eliminated, or is in a cloud) is drawn from the newer
      snapshot, or not drawn at all
    - **positions** use `a + (b - a) × t`
    - **`dir` is discrete**: don't interpolate it, take the nearer snapshot's value
    - **wrap jumps**: if `|b.x - a.x| > width / 2` (or the same for `y`), the unit wrapped, so
      don't interpolate and use `b`
    - **shells** are handled the same way, by id
  - If `renderTime` is newer than the latest snapshot (lag spike), clamp to the latest. Don't
    extrapolate, at least not yet.
- **Renderer:** draw `interp.sample(performance.now() - INTERP_DELAY)` instead of `latest`.
  Keep `latest` for the HUD.

### Checkpoint

Compare the game at 30 Hz with and without interpolation (a `?interp=0` URL flag is handy). Then
try the server at **10 Hz** (`tick_ms: 100`). With interpolation it should still look smooth,
which is very satisfying.

## Part B: Measuring latency

- Channel: `handle_in("ping", %{"t" => t}, socket)` returns `{:reply, {:ok, %{t: t}}, socket}`.
- Client: every 2 s, `channel.push("ping", { t: performance.now() })`. In
  `.receive("ok", ({t}) => ...)`, `rtt = performance.now() - t`. Show it in a corner of the HUD.
- Note that `{:reply, ...}` from `handle_in` is the request/response primitive of channels. You
  haven't needed it before because input is fire-and-forget.

## Part C: Disconnects and reconnects

### Concept: monitors

A **monitor** is a one-way watch on another process. When the watched process dies, the watcher
receives `{:DOWN, ref, :process, pid, reason}` as a normal message. Unlike links, monitors never
kill the watcher. That's exactly what the game server needs: "tell me when a player's channel
goes away".

### Steps

- In `GameServer.join/2`'s `handle_call`, the `from` argument is `{caller_pid, tag}`. The caller
  is the **channel process**. Call `Process.monitor(caller_pid)` and store
  `%{ref => slot}` in the server state. If the same player rejoins, monitor the new pid (and
  `Process.demonitor/2` the old one if it's still around).
- `handle_info({:DOWN, ref, :process, _pid, _reason}, state)`:
  - look up the slot, and reset that side's input to `Input.new()` (otherwise the tank keeps
    driving with whatever key was held when the tab closed)
  - mark the slot `:disconnected` with a timestamp, and include `connected: %{p1: true, p2: false}`
    in the snapshot so the opponent sees "Opponent disconnected…"
  - schedule `{:forfeit_check, slot}` in 15 s
- `{:forfeit_check, slot}`: if the slot is still disconnected, end the round with the *other*
  side as winner (add `Game.forfeit(state, slot)` in the core).
- **Reconnect** is mostly already done: the Phoenix JS client rejoins automatically, and `join/2`
  is idempotent by player id. Test it by restarting your Wi-Fi, or by running
  `CombatWeb.Endpoint.broadcast("player_socket:" <> player_id, "disconnect", %{})` in iex.
  That's the socket `id/1` from guide 07 paying off.

Optional: pause the game while someone's disconnected (a `:paused` status in the core, where
`tick/2` does nothing). Is it fairer, or abusable? Decide for yourself.

## Part D: Cleaning up idle matches

Without cleanup, every abandoned match ticks forever.

- In `GameServer`, every 30 s handle an `:idle_check` message. If **no slot is connected** (or
  the game is `:over` and nobody has been connected for 60 s), return
  `{:stop, :normal, state}`.
- Because the child is `:transient` (guide 06), a `:normal` stop is **not** restarted. Verify
  this with `DynamicSupervisor.count_children/1`.
- About `terminate/2`: it's called when the GenServer itself returns `{:stop, ...}`, but **not**
  when it's killed or when its supervisor shuts it down, unless it's trapping exits. Never put
  essential logic in it. Use it here only to `Logger.info("match ended")`.

Tests: a manual-tick server with no joins handles a sent `:idle_check` by exiting with `:normal`.
Use `Process.monitor/1` in the test and
`assert_receive {:DOWN, _, :process, ^pid, :normal}`. Monitors are useful in tests too.

## Part E: Sound

- Create `assets/js/game/sound.js` using the **WebAudio API**: an `AudioContext`, an
  `OscillatorNode` of `type: "square"` (very 8-bit), and a `GainNode` with a quick decay envelope.
- `beep(freq, duration)` builds an oscillator, connects it, starts it, and stops it at
  `ctx.currentTime + duration`.
- Map snapshot `events` to sounds: `fire` is a short high blip, `hit` a falling noise burst (try a
  frequency ramp with `exponentialRampToValueAtTime`), and `game_over` a little arpeggio.
- Browsers block audio until a **user gesture**, so call `ctx.resume()` on the first keydown or
  click.
- Events can be **missed** if the client drops a snapshot. For sound that's fine. For anything
  that matters (scores), always use state, never events.

Make your own sounds. Don't sample the original's.

## Part F: Small polish list

Pick whatever you fancy:

- Screen shake on hit (offset the canvas transform for a few frames).
- Pixel-art sprites per direction (the hint in guide 08).
- Show both players' names: an optional name field in the lobby, stored in Presence metadata.
- A mute toggle remembered in `localStorage`.
- Run a `mix test --cover` report and find untested core code.

## Checkpoint

- Play on two *different machines* on your network: `mix phx.server` binds to localhost by
  default. Change `http: [ip: {0, 0, 0, 0}, ...]` in `config/dev.exs` to allow LAN access, and
  connect with your machine's LAN IP.
- Turn on network throttling in one browser. The game stays smooth (just a bit more delayed), RTT
  shows the throttling, and closing one window leads to a forfeit 15 s later.
- After everyone leaves, the match process disappears within about a minute.

Next: [14 — Deployment (optional)](14-deployment.md)
