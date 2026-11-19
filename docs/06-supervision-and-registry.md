# 06 — Supervision & Registry

## Goal

Matches are started on demand under a supervisor and found by their 4-letter room code instead
of a pid. A crash in one match never affects any other match, or the web server. The web layer
gets one tidy public API, `Combat.Matches`.

## Concepts

### Links, exits and why supervisors exist

When you `start_link` a process, the two processes are **linked**: if one dies abnormally, the
other receives an exit signal and (by default) dies too. You saw this at the end of guide 05 when
killing the game also killed your iex shell.

A **supervisor** is a process that *traps exits*. Instead of dying when a child dies, it receives
a message and **restarts the child** according to a strategy. That's the heart of OTP's "let it
crash" philosophy: don't write defensive code for every impossible situation. Let the process
die, and let its supervisor put a known-good one back.

### Restart values

Each child spec has a `restart` value:

| Value | Restarted when it exits with... |
|---|---|
| `:permanent` (default) | any reason, even a normal stop |
| `:transient` | an **abnormal** reason only (a crash), not `:normal` or `:shutdown` |
| `:temporary` | never |

A match that ends normally (game over, everyone left) should stay dead, but one that crashed
should come back. So matches are **`:transient`**. Set it with `use GenServer, restart: :transient`.

Supervisors also have **restart intensity**, `max_restarts` within `max_seconds` (default 3 in 5).
If children crash faster than that, the *supervisor itself* gives up and crashes, escalating to its
parent. This stops infinite crash loops.

### `Supervisor` vs `DynamicSupervisor`

- A `Supervisor` (like the one in `application.ex`) has a **fixed list** of children known at boot.
- A `DynamicSupervisor` starts with **no children** and has them added at runtime with
  `DynamicSupervisor.start_child/2`. That's exactly what we want for matches created when someone
  clicks "New game".

### Registry: names for dynamic processes

You can't give each match an atom name (`:"match_QXKB"`), because atoms are never
garbage-collected and you'd leak one per match forever. **`Registry`** is a local key/value store
of processes. It maps any term (our match id string) to a pid, and it **removes the entry
automatically** when the process dies.

You use it through a **via tuple**, which any GenServer function accepts wherever it wants a name
or pid:

```elixir
{:via, Registry, {Combat.MatchRegistry, "QXKB"}}
```

Two great properties:

1. `GenServer.start_link(..., name: via)` **fails** with `{:error, {:already_started, pid}}` if the
   key is taken. Uniqueness is enforced atomically, with no race window.
2. `GenServer.call(via, ...)` looks up the pid for you.

## Steps

### 1. Add the Registry and DynamicSupervisor to the tree

In `lib/combat/application.ex`, add **before** `CombatWeb.Endpoint`:

```elixir
{Registry, keys: :unique, name: Combat.MatchRegistry},
{DynamicSupervisor, name: Combat.MatchSupervisor, strategy: :one_for_one},
```

Order matters. Children start top to bottom and shut down bottom to top. The endpoint (which
accepts players) must start *after* the things it relies on, and stop *before* them.

### 2. Register game servers by id

In `Combat.GameServer`:

- `use GenServer, restart: :transient`.
- Add `via(id)`, which returns the via tuple above.
- `start_link/1` always passes `name: via(id)`, so drop the `:name` option from guide 05.
- Client functions keep taking a `server` argument. A pid and a via tuple both work, so the
  existing tests keep passing.

### 3. `Combat.Matches` (`lib/combat/matches.ex`): the public API

The web layer will **only** talk to this module and never to `GameServer` directly.

| Function | Returns | Notes |
|---|---|---|
| `create_match(opts \\ [])` | `{:ok, id}` | Generates an id and starts a child under `Combat.MatchSupervisor`. Other `opts` (e.g. `tick_ms: :manual`, `arena:`) are forwarded to `GameServer.start_link/1`, which tests rely on |
| `whereis(id)` | `pid \| nil` | `Registry.lookup/2` |
| `exists?(id)` | boolean | |
| `list_ids()` | `[id]` | Registry select. See the hint |
| `set_input(id, slot, input)` | `:ok` | Delegates via `GameServer.via(id)` |
| `start_game(id)`, `snapshot(id)`, `arena_info(id)` | | Delegate |
| `stop_match(id)` | `:ok \| {:error, :not_found}` | `DynamicSupervisor.terminate_child/2` |

**Room codes:** 4 random letters from an alphabet without confusable letters (say no `I`, `O`,
`L`). On `{:error, {:already_started, _}}`, try again with a new code (recursion with a retry
limit). You don't need to check whether a code is free *before* starting. Let the Registry be
the source of truth.

<details><summary>Hint: generating the code</summary>

`for _ <- 1..4, into: "", do: <<Enum.random(@alphabet)>>` where `@alphabet` is a charlist like
`~c"ABCDEFGHJKMNPQRSTUVWXYZ"`. Note that `<<char>>` turns a codepoint into a one-byte binary.
</details>

<details><summary>Hint: listing all registry keys</summary>

```elixir
Registry.select(Combat.MatchRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
```

That's an ETS match spec: "for every `{key, pid, value}`, return the key". Match specs look
alien. Read the `Registry.select/2` docs once and move on.
</details>

### 4. Calling a match that doesn't exist

Try in iex: `GenServer.call(GameServer.via("NOPE"), :snapshot)`. It **exits** (it isn't an
exception you can `rescue`) with `{:noproc, ...}`. Meanwhile `GenServer.cast` to a missing name
silently does nothing.

Decide on your API's contract. A good one:

- `snapshot/1`, `arena_info/1` and `start_game/1` return `{:ok, result} | {:error, :not_found}`.
  Wrap the call in `try ... catch :exit, {:noproc, _} -> {:error, :not_found}`. Checking
  `whereis/1` first is **not** enough, because the process could die between the check and the
  call. Think it through: why?
- `set_input/3` stays a fire-and-forget `:ok`.

## Tests (`test/combat/matches_test.exs`)

Matches now run under the *application's* supervisor rather than the test's, so they outlive each
test. Clean up with `on_exit(fn -> Matches.stop_match(id) end)`. Don't use `async: true` for tests
that list *all* matches.

- `create_match/0` returns a 4-letter id, and `whereis/1` finds a pid.
- Two `create_match/0` calls give different ids.
- `snapshot("ZZZZ")` returns `{:error, :not_found}`.
- **The crash test:** get the pid, `Process.exit(pid, :kill)`, then wait until `whereis/1`
  returns a **different** pid. Use a small polling helper with a timeout. Never use a bare
  `Process.sleep`.
- `stop_match/1` makes `whereis/1` return `nil`, and the match **stays** stopped (`:transient`).

## Checkpoint

In `iex -S mix`:

```elixir
iex> {:ok, id} = Combat.Matches.create_match()
iex> pid = Combat.Matches.whereis(id)
iex> Process.exit(pid, :kill)
iex> Combat.Matches.whereis(id)        # a new pid! And your shell survived this time.
iex> DynamicSupervisor.count_children(Combat.MatchSupervisor)
```

Think about what the restart *means*. The new process has a **fresh** game, so the scores are
gone. For a 2-minute arcade round that's acceptable. Write down what you'd do if it weren't. (One
idea: write the state to ETS every N ticks and reload it in `init`.)

## Stretch goals

- Open LiveDashboard (http://localhost:4000/dev/dashboard) next to your iex shell. Start a few
  matches, then find them in the *Processes* tab (sort by name, or look under
  `Combat.MatchSupervisor` in the *Applications* tab's tree). Kill one from iex and watch a
  replacement appear with a new pid.
- Put the registry value to use: register with `Registry.register/3`-style metadata such as the
  mode and creation time, so `list_ids/0` can become a lobby listing.

Next: [07 — Channels & PubSub](07-channels-and-pubsub.md)
