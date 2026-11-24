# 14 — Observability & telemetry

## Goal

You can see what the running game is doing without attaching a debugger or sprinkling
`IO.inspect`. LiveDashboard charts how long each tick takes, how many matches are running and
how rounds end. Slow ticks show up as log lines tagged with their match id. You can find any match
process and inspect it live. Tests prove that the events you rely on are actually emitted.

## Concepts

### Three ways to look inside

| Tool | Answers | Example |
|---|---|---|
| **Logs** | "What happened, and in what order?" | `match QXKB started`, `tick loop fell behind by 400 ms` |
| **Metrics** | "How much, how often, how long?" over time | ticks take 0.2 ms on average, 3 matches running |
| **Introspection** | "What is this process doing *right now*?" | mailbox length, memory, current state |

The BEAM is unusually good at the third one. Every process can be inspected live, in production,
without stopping anything. This guide uses all three, but most of it is about metrics, because
that's what `:telemetry` is for.

### `:telemetry`: events, handlers, metrics

[`:telemetry`](https://hexdocs.pm/telemetry) is a tiny library that almost the whole Elixir
ecosystem uses (Phoenix, Ecto, Finch, Oban, …). It has three parts, and it's worth keeping them
separate in your head:

1. **Events.** Code *announces* that something happened by calling
   `:telemetry.execute(event_name, measurements, metadata)`:
   - `event_name` is a list of atoms, e.g. `[:combat, :tick, :stop]`.
   - `measurements` is a map of numbers, e.g. `%{duration: 1234}`.
   - `metadata` is a map of anything that describes the context, e.g. `%{match_id: "QXKB"}`.

   If nobody is listening, this costs almost nothing.
2. **Handlers.** Code *listens* with `:telemetry.attach(handler_id, event_name, &Mod.fun/4,
   config)`. The handler is called with `(event_name, measurements, metadata, config)`.
3. **Metrics.** [`Telemetry.Metrics`](https://hexdocs.pm/telemetry_metrics) lets you *declare*
   aggregations such as "a summary of the `duration` measurement of `[:combat, :tick, :stop]`".
   A **reporter** (LiveDashboard, a console printer, Prometheus, …) attaches the handlers for
   you and does the aggregating.

The library that emits an event doesn't know or care who's listening. That's the same idea as
PubSub in guide 05: the game server announces, and the web layer decides what to do with it.

### Handlers run in the emitting process

This is the most important fact about `:telemetry`, and the easiest to forget. There is no
background process. When your `GameServer` calls `:telemetry.execute/3`, **every attached handler
runs right there, inside the `GameServer`, before `execute` returns**.

Two consequences:

- **A slow handler slows the tick.** Handlers must be cheap. Don't do I/O, `GenServer.call` or
  heavy work in them. If you need to, send a message to another process and return.
- **A handler sees the emitting process's context.** That includes its `Logger.metadata`. A
  handler that logs from inside the `GameServer` gets the `match_id` tag from guide 05 for free.

If a handler raises, `:telemetry` **detaches it** and carries on. Your game keeps running, but
that handler stays silent until it's attached again. That's safe, but it can be confusing if you
don't know about it.

### Spans

Timing something is so common that `:telemetry` has a helper for it:

```elixir
:telemetry.span([:combat, :tick], start_metadata, fn ->
  result = do_the_work()
  {result, stop_metadata}
end)
```

`span/3` emits three related events:

| Event | When | Measurements |
|---|---|---|
| `[:combat, :tick, :start]` | before the function runs | `system_time`, `monotonic_time` |
| `[:combat, :tick, :stop]` | after it returns | `duration`, `monotonic_time` |
| `[:combat, :tick, :exception]` | if it raises | `duration`, plus `kind`, `reason`, `stacktrace` in metadata |

`span/3` then returns `result`. Durations are in **native time units**, the VM's internal clock
resolution. Never assume they're nanoseconds or microseconds. Metrics convert them for you with
`unit: {:native, :millisecond}`.

### Metric types

| Function | Shows | Good for |
|---|---|---|
| `counter/2` | how many times the event fired | rounds finished, shells fired |
| `sum/2` | running total of a measurement | bytes sent |
| `last_value/2` | the most recent value | matches running right now |
| `summary/2` | min, max, mean and percentiles of a measurement | tick duration |
| `distribution/2` | a histogram | tick duration, when you care about the shape |

A metric's name encodes its event and measurement. `"combat.tick.stop.duration"` means "the
`:duration` measurement of the `[:combat, :tick, :stop]` event".

### Tags and cardinality

Metrics can be **tagged** with metadata (`tags: [:match_id]`), which splits them into one series
per tag value. That's handy, but every distinct value is a new series. Match ids are random and
endless, so tagging by match id gives you a new series for every match ever played. In
LiveDashboard during development that's fine. In a real metrics system it's the classic way to run
up a bill or knock the system over. Prefer tags with a **small, fixed set of values**: the game
mode, the winner, the event type.

### Where telemetry belongs: not in the core

`Combat.Game` is pure: data in, data out, no side effects (guide 02). Emitting telemetry *is* a
side effect, so it goes in the **imperative shell**: the `GameServer` and the channel. The core
already reports what happened through `state.events` (guide 04), so the shell can turn those
events into telemetry without the core knowing.

## Steps

### 1. Tour what you already have

Phoenix generated most of the plumbing in guide 01. Read `lib/combat_web/telemetry.ex` again:

- `metrics/0` lists the metrics LiveDashboard charts. Phoenix's own events are already there:
  endpoint requests, socket connects, channel joins and `phoenix.channel_handled_in.duration`
  tagged by `event`.
- `periodic_measurements/0` is empty. You'll fill it in step 5.
- The commented-out `Telemetry.Metrics.ConsoleReporter` is a reporter that prints every metric
  to the terminal.

Then find the `live_dashboard "/dashboard", metrics: CombatWeb.Telemetry` line in `router.ex`.
That `metrics:` option is the whole connection between the two.

Start the server, open http://localhost:4000/dev/dashboard/metrics, and play a match in two
tabs. Open the **Phoenix** group and watch `phoenix.channel_handled_in.duration` for the
`"input"` event. That's every key press, measured with zero code from you.

> LiveDashboard only shows data from the moment you open the page. Charts start empty, and a
> page refresh clears them. Stretch goal 1 fixes that.

### 2. Attach a handler by hand

Before relying on reporters, see the raw events. In `iex -S mix phx.server`, attach a handler to
`[:phoenix, :channel_handled_in]` with `:telemetry.attach/4`. An anonymous function is fine
here, in iex, because you're only experimenting. Have it `IO.inspect` the measurements and
metadata.

Press some keys in a game tab and look at what arrives:
- **Measurements:** what's in the map, and in what unit is `duration`?
- **Metadata:** which keys does Phoenix include? Which would make good tags?

`:telemetry.detach/1` with the same handler id stops it.

`:telemetry.list_handlers([])` lists every handler that's attached. Look for the ones
LiveDashboard added while its Metrics page was open.

You'll also see an info-level log message about using an anonymous function as a handler. In application code,
always pass a capture of a **named function in a module** (`&MyModule.handle_event/4`), which the
VM can call faster.

### 3. Time the tick with a span

In `GameServer.handle_info(:tick, state)`, wrap the work (the `Game.tick/2` call, and the snapshot
if you like) in `:telemetry.span([:combat, :tick], ...)`.

- **Metadata:** include `match_id` in both the start and stop metadata. Include `mode` too once
  you've done guide 10.
- **Return value:** the function passed to `span/3` returns `{result, stop_metadata}`, and `span/3`
  returns `result`. Make the result the new game state, so the rest of `handle_info` barely
  changes.

If you did the guide 05 stretch goal with `:telemetry.execute/3` and a hand-measured duration,
replace it with the span. Also give the tick-loop catch-up guard from guide 05's hint its own
event, e.g. `[:combat, :tick, :skipped]` with a measurement of how many milliseconds were lost.
It's the most interesting thing that can happen in the loop.

<details><summary>Hint: what is a span's metadata for?</summary>

Start metadata describes the situation *before* the work, and stop metadata the situation
*after*. For the tick, `match_id` belongs in both. Stop metadata is where you can put something
learned during the work, such as the game's status after the tick.
</details>

### 4. Turn game events into telemetry

After the tick, the new state's `events` list (guide 04) holds what happened this tick: `:fire`,
`:hit` and `:game_over`. In the `GameServer`, loop over them and emit one telemetry event each:

- `[:combat, :game, :event]` with metadata `%{type: ..., match_id: ...}` and a measurement of
  `%{count: 1}`.
- For `:game_over`, also emit `[:combat, :match, :finished]` with the winner (and the mode, after
  guide 10) in the metadata.

Also emit `[:combat, :match, :created]` from `init/1`. Put the small emitting helpers in one
module, `Combat.Telemetry` (`lib/combat/telemetry.ex`), so that event names are written in one
place and not scattered across files.

<details><summary>Hint: why not emit from <code>Game.tick/2</code> directly?</summary>

You could, and it would work. But then the core has a side effect, and every core test would
emit telemetry events too. Two tests running the same match id with `async: true` would see each
other's events. Keeping the core pure means it stays trivially testable, and the shell decides
what's worth announcing.
</details>

### 5. Count matches with the poller

Some numbers aren't events. "How many matches are running?" is a *level*, not a thing that
happens. For those, `:telemetry_poller` (already in `CombatWeb.Telemetry`) calls a function every
10 seconds, and that function emits an event with the current value.

- Add `Combat.Telemetry.measure_matches/0`. It counts the registered matches with
  `Registry.count/1` and emits `[:combat, :matches]` with `%{count: n}`.
- Add `{Combat.Telemetry, :measure_matches, []}` to `periodic_measurements/0`.

**Check this before you trust it.** Look at the child order in `application.ex`.
`CombatWeb.Telemetry` starts *first*, before `Combat.MatchRegistry`, and the poller takes its first
measurement as soon as it starts. If that first call raises, the poller **silently removes the
measurement** and never calls it again. Make `measure_matches/0` cope with the registry not
existing yet (`Process.whereis/1` is enough), and think about why moving `CombatWeb.Telemetry`
further down the child list is not the better fix.

The 10-second period is slow for experimenting. You can lower it while you develop.

### 6. Define the metrics

Add your metrics to `CombatWeb.Telemetry.metrics/0`:

| Metric | Type | Options |
|---|---|---|
| `"combat.tick.stop.duration"` | `summary` | `unit: {:native, :millisecond}` |
| `"combat.tick.skipped.lost_ms"` (or whatever you named it) | `sum` | |
| `"combat.matches.count"` | `last_value` | |
| `"combat.game.event.count"` | `counter` | `tags: [:type]` |
| `"combat.match.finished.count"` | `counter` | `tags: [:winner]` (and `:mode`) |

The `count` measurement name is a convention for counters, but a counter counts events however
they're named. The measurement value isn't used.

**Tags must be strings or atoms that display well.** If a tag value is a module, such as
`Combat.Game.Modes.Tank`, use the `tag_values:` option to map the metadata to something short,
e.g. `"tank"`.

Reload the Metrics page. A **Combat** group appears. Play a round and watch the charts move.

<details><summary>Hint: <code>CombatWeb.Telemetry</code> refers to <code>[:combat, ...]</code> events. Is that a boundary problem?</summary>

The web layer is allowed to depend on the core, so `CombatWeb` knowing about `Combat` events is
fine. The reverse would be the problem. Metric definitions are just strings, so there isn't even
a compile-time dependency. If it bothers you, a common alternative is to move the whole
`Telemetry` supervisor to `Combat.Telemetry.Supervisor` and point LiveDashboard at it.
</details>

### 7. Log slow ticks from a handler

A tick at 30 Hz has a budget of 33 ms. Alerting on slow ticks is a job for a handler.

- Add `Combat.Telemetry.SlowTickLogger` with `attach/0` and `handle_event/4`.
- `handle_event/4` receives `[:combat, :tick, :stop]`. If the duration is over a threshold
  (convert it with `System.convert_time_unit/3`; try 5 ms), it calls `Logger.warning/1` with the
  duration.
- Call `SlowTickLogger.attach()` from `Combat.Application.start/2`, before the supervisor starts.

Because the handler runs **inside the `GameServer`**, the log line carries the `match_id`
metadata from guide 05 without passing it anywhere.

### 8. Tag channel logs

The channel process has its own `Logger.metadata`. In `GameChannel.join/3`, set `match_id`,
`player_id` and (once known) `slot`. Add any new keys to the formatter's `metadata:` list in
`config/config.exs`. Now a log line from a channel tells you which player it was about.

Keep logs for things that happen *occasionally*: joins, leaves, rounds ending, errors. Never log
on every tick or every input. That's 30 lines per second per match, and it hides everything else.

### 9. Inspect a live match

With a match running, try each of these and note what you learn:

- **LiveDashboard Processes page:** find a `GameServer` process (sort by reductions: it does
  more work than almost anything else). Open it to see its mailbox length, memory and current
  function. Kill it from the dashboard and watch guide 06's supervisor replace it.
- **`Process.info(pid, [:message_queue_len, :memory, :reductions])`** in iex: the same numbers in
  the shell. A `message_queue_len` that keeps growing means the process can't keep up.
- **`:sys.get_state(pid)`**: the server's whole state, live.
- **`:sys.trace(pid, true)`**: prints every message the process receives and every state change.
  At 30 ticks per second this floods your terminal within a second, so turn it off again with
  `:sys.trace(pid, false)`. Try it once to see what a GenServer's life looks like.

### 10. Tests

`:telemetry` ships a test helper. `:telemetry_test.attach_event_handlers(self(), events)` attaches
handlers that **send each event to your test process** as a message:

```elixir
{event_name, ref, measurements, metadata}
```

`ref` is the reference that `attach_event_handlers/2` returns. Then `assert_receive` works as
usual. Write tests for:

- A manual-tick `GameServer` (guide 05) that receives `:tick` emits `[:combat, :tick, :stop]` with a
  `duration` and the right `match_id`.
- A round that ends emits `[:combat, :match, :finished]` with the winner. Reuse your guide 04 setup
  that runs a match to the end.
- `measure_matches/0` emits a count that goes up when you create a match.

Detach the handlers in `on_exit` with `:telemetry.detach(ref)`. Handlers are global, so a test that
forgets to detach can receive events from other tests. Telemetry events also come from every
`GameServer` in the VM, so **match on your own `match_id`** in `assert_receive`. Otherwise a test
running alongside yours can satisfy it.

## Checkpoint

- The LiveDashboard Metrics page has a **Combat** group. During a match, the tick-duration summary
  stays well under a millisecond, and `combat.matches.count` goes up and down as you create and
  leave matches (within one poll period).
- Finishing a round increments `combat.match.finished.count` under the right winner.
- Temporarily add `Process.sleep(40)` inside the span in `handle_info(:tick, ...)`. Within a
  second:
  - tick duration jumps on the chart
  - `SlowTickLogger` warnings appear, tagged with the match id
  - the game visibly stutters
  - your catch-up guard starts reporting skipped time

  Remove the sleep and everything recovers.
- You can find a running match in the Processes page and read its state with `:sys.get_state/1`.
- Your telemetry tests pass, including with `mix test --repeat-until-failure 20`.

## Stretch goals

1. **Metrics history.** LiveDashboard accepts a `metrics_history:` option in the router that
   returns recent data points for a metric, so charts aren't empty on page load. Write a small
   GenServer that keeps a circular buffer per metric (attach to the metric events, store the last
   few hundred values). The
   [LiveDashboard metrics guide](https://hexdocs.pm/phoenix_live_dashboard/metrics_history.html)
   walks through it.
2. **Player latency.** The client already measures round-trip time in guide 13, but only the
   browser knows it. Send the last RTT in the next `"ping"` payload, and emit
   `[:combat, :player, :rtt]` from the channel. Chart it as a `summary`. What does it look like
   with network throttling turned on?
3. **Snapshot size.** Snapshots are the biggest thing you send. Measure one with
   `:erlang.external_size/1` (an approximation; encoding to JSON again just to measure would double
   the work). Emit it on every tick, or only every 30th, and decide which is worth the cost.
4. **Mailbox watch.** Use the poller to report the largest `message_queue_len` across all
   `GameServer` processes (`Registry.select/2` for the pids, then `Process.info/2`). A slowly
   growing number is the earliest warning sign that the server can't keep up.
5. **Production metrics.** LiveDashboard is a development tool here. For production, look at
   [`telemetry_metrics_prometheus`](https://hexdocs.pm/telemetry_metrics_prometheus) or
   [PromEx](https://hexdocs.pm/prom_ex), which expose the same `metrics/0` list to Prometheus and
   Grafana. The metric definitions you wrote don't change, only the reporter does. Guide 15 is a
   good place to try this.
6. **Tracing.** [OpenTelemetry for Erlang/Elixir](https://opentelemetry.io/docs/languages/erlang/)
   builds distributed traces from the same `:telemetry` events Phoenix emits. Follow one input
   from the browser through the channel into the `GameServer`.

Next: [15 — Deployment (optional)](15-deployment.md)
