# 05 — The GenServer

## Goal

A `Combat.GameServer` process owns one match. It ticks about 30 times a second, accepts input,
and broadcasts a snapshot after every tick. You'll drive a whole match from `iex` with no browser
involved.

## Concepts

### Processes in 60 seconds

An Elixir process is a tiny isolated thing with its own memory and a **mailbox**. It handles one
message at a time, in order. Processes share nothing: the only way to affect another process is
to send it a message. That's why one process per match is so natural. All updates to a match are
automatically serialised, so you never need locks.

### GenServer: a process with a standard shape

`GenServer` is an OTP **behaviour**, a contract where OTP writes the receive loop and you write the
callbacks. Each callback receives the current state and returns the next state:

| Callback | Triggered by | Returns |
|---|---|---|
| `init(arg)` | `GenServer.start_link/3` | `{:ok, state}` (optionally `{:ok, state, {:continue, term}}`) |
| `handle_call(msg, from, state)` | `GenServer.call/3` (caller **waits** for a reply) | `{:reply, reply, new_state}` |
| `handle_cast(msg, state)` | `GenServer.cast/2` (fire and forget) | `{:noreply, new_state}` |
| `handle_info(msg, state)` | any other message (`send/2`, timers, monitors) | `{:noreply, new_state}` |
| `handle_continue(term, state)` | a `{:continue, term}` return value | `{:noreply, new_state}` |
| `terminate(reason, state)` | shutdown (only reliably called in some cases, see guide 13) | ignored |

The convention is to put **client API** functions (run in the *caller's* process) and **server
callbacks** (run in the *GenServer's* process) in the same module, client API on top. The client
functions are thin wrappers around `GenServer.call/cast`. It's worth noticing which process each
function actually runs in.

### call or cast?

- `call` blocks the caller until the server replies (default timeout 5 s). Use it when you need an
  answer, or when you *want* backpressure.
- `cast` returns immediately. Use it for "here's some information, carry on".

Player input is a `cast`. The channel process shouldn't wait for the game loop, and if one input
is slightly late, the next one fixes it.

### Ticking: `Process.send_after/4`

A process can schedule a message to itself:

```elixir
Process.send_after(self(), :tick, 33)
```

and handle it in `handle_info(:tick, state)`. If you re-schedule from inside the handler, you get
a loop. **The drift problem:** the handler takes a few ms, so "33 ms after I finished" is really
~35 ms between ticks, and the game runs slow. The fix is to schedule against an **absolute
time**:

```elixir
next_at = state.next_tick_at + @tick_ms
Process.send_after(self(), :tick, next_at, abs: true)
```

`abs: true` means `next_at` is a point in time on the `System.monotonic_time(:millisecond)` clock
rather than a delay. Monotonic time only moves forward, so it never jumps when the wall clock is
adjusted.

### Fixed timestep

Pass the **constant** `dt = @tick_ms / 1000` to `Combat.Game.tick/2` on every tick, rather than
measuring real elapsed time. That makes the simulation deterministic (the same inputs always give
the same result) and keeps it identical between tests and production. Because of absolute
scheduling, ticks still happen on time in the long run.

### PubSub (preview)

`Phoenix.PubSub` is a publish/subscribe system already running in your app (`Combat.PubSub`, look
in `application.ex`). Any process can subscribe to a topic string, and any process can broadcast
to it. Every subscriber receives the message in its mailbox:

```elixir
Phoenix.PubSub.subscribe(Combat.PubSub, "match:QXKB")
Phoenix.PubSub.broadcast(Combat.PubSub, "match:QXKB", {:snapshot, snap})
```

The game server **doesn't know or care who's listening.** It just announces. That keeps
`lib/combat` free of any dependency on `lib/combat_web`. Guide 07 has channels subscribe.

## Steps

### 1. `Combat.GameServer` (`lib/combat/game_server.ex`)

`use GenServer`. Server state (a plain map is fine):

```elixir
%{
  id: "QXKB",                  # match id
  game: %Combat.Game.State{},
  tick_ms: 33 | :manual,
  next_tick_at: integer | nil  # monotonic ms
}
```

**Client API:**

| Function | Kind | Purpose |
|---|---|---|
| `start_link(opts)` | | `opts`: `:id` (required), `:arena` (default `Arenas.maze()`), `:tick_ms` (default `33`), `:name` (optional, passed to `GenServer.start_link`) |
| `set_input(server, slot, %Input{})` | cast | Store a player's input |
| `start_game(server)` | call | Calls `Game.start/1`, replies `:ok` |
| `snapshot(server)` | call | Replies `Game.snapshot(game)` |
| `arena_info(server)` | call | Replies `Game.arena_info(game)` |
| `topic(match_id)` | plain function | Returns `"match:" <> match_id`. Everyone builds the topic through this one function |

**Callbacks:**

- `init/1`: build the game state. If `tick_ms` is an integer, schedule the first tick (set
  `next_tick_at` to now + `tick_ms`). If it's `:manual`, schedule nothing. Tests will send
  `:tick` themselves.
- `handle_cast({:set_input, slot, input}, state)`: update `game` via `Game.set_input/3`.
- `handle_call(...)` for `start_game`, `snapshot` and `arena_info`.
- `handle_info(:tick, state)`:
  1. `game = Game.tick(state.game, dt)`
  2. broadcast `{:snapshot, Game.snapshot(game)}` on `topic(id)`
  3. if not manual, schedule the next tick with `abs: true`
  4. return `{:noreply, %{state | game: game, next_tick_at: ...}}`

<details><summary>Hint: what if the server falls badly behind?</summary>

If the machine stalls for a second, `next_tick_at` ends up in the past. With `abs: true`, a time
in the past fires immediately, so the server rapidly fires ~30 catch-up ticks. That's arguably
correct (the simulation catches up), but it hammers clients with snapshots. A common guard: if
`next_at < now - 5 * @tick_ms`, reset `next_at = now + @tick_ms` and accept the lost time. Add a
`Logger.warning` when that happens, which makes a great debugging aid.
</details>

<details><summary>Hint: <code>{:continue, ...}</code> and why it exists</summary>

`init/1` runs while `start_link` **blocks** its caller. Anything slow in `init` (loading a big
arena, contacting a service) delays whoever started the process, which is usually a supervisor
starting its other children. Returning `{:ok, state, {:continue, :setup}}` lets `init` return
right away and do the slow part in `handle_continue(:setup, state)` before any other message is
processed. Our init is cheap, so it's optional here, but try it to see the order of things.
</details>

### 2. Logging

Add `require Logger` and log at `:info` when a match starts and ends. Inside a GenServer, use
`Logger.metadata(match_id: id)` in `init/1`, so every later log line from that process is tagged.
To see the tag, add `:match_id` to the `metadata:` list in the logger formatter config in
`config/config.exs` (look for `config :logger, :default_formatter`).

## Tests (`test/combat/game_server_test.exs`)

New tools:

- **`start_supervised!/1`** starts a process under the test's own supervisor and stops it when
  the test ends. Use it instead of `start_link` in tests:
  `pid = start_supervised!({Combat.GameServer, id: "TEST", tick_ms: :manual})`.
  The `{Module, opts}` tuple form calls `Module.child_spec(opts)`, which `use GenServer` defined
  for you.
- **`:sys.get_state(pid)`** peeks at any OTP process's state. It's great for tests and debugging,
  but never use it in application code.
- **`assert_receive pattern, timeout`** waits for a message in the test process's mailbox.

Tests to write:

- After `start_game/1` and a `set_input` with `forward: true`, sending `send(pid, :tick)` 30 times
  moves `p1`. Check via `snapshot/1`, because a `call` is processed only after all the earlier
  messages in the mailbox, so the call also acts as a synchronisation point. That's a key insight!
- A test that subscribes to `GameServer.topic("TEST")`, sends one `:tick`, and does
  `assert_receive {:snapshot, %{status: "playing"}}`.
- With the real timer (`tick_ms: 33`), you receive at least 25 snapshots within 1100 ms. Tag it
  `@tag :slow` if you like, and exclude it by default in `test/test_helper.exs`.

## Checkpoint: drive a match from iex

```elixir
iex -S mix
iex> alias Combat.{GameServer, Game.Input}
iex> {:ok, pid} = GameServer.start_link(id: "IEX1")
iex> Phoenix.PubSub.subscribe(Combat.PubSub, GameServer.topic("IEX1"))
iex> GameServer.start_game(pid)
iex> GameServer.set_input(pid, :p1, %Input{forward: true, fire: true})
iex> flush()        # prints every snapshot that has piled up in your shell's mailbox
iex> GameServer.snapshot(pid)
```

Watch `p1`'s `x` grow, and see a shell appear. Now try `Process.exit(pid, :kill)` and then
`Process.alive?(pid)`. Notice that your iex shell **also crashed and restarted**: you
`start_link`ed, so the processes were linked. That's exactly the problem guide 06 solves.

## Stretch goals

- Add `:telemetry.execute([:combat, :tick], %{duration: native_time}, %{match_id: id})` around the
  tick, then log the duration in a handler. You'll know exactly how much CPU headroom you have.
  Guide 14 comes back to this properly, with `:telemetry.span/3` and a chart in LiveDashboard.
- Use `:timer.tc/1` in iex to measure one `Game.tick/2` call. (Expect microseconds.)

Next: [06 — Supervision & Registry](06-supervision-and-registry.md)
