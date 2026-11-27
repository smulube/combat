# 15 — Deployment (optional)

## Goal

Get the game onto the internet so a friend can play from their own home, and understand what
would change if you ran more than one server.

## Concepts

### Releases

`mix release` builds a **self-contained bundle**: your compiled code, all dependencies and the
Erlang runtime, with no need for Elixir or Mix on the server. You run it with
`_build/prod/rel/combat/bin/combat start`. Configuration that depends on the environment
(secrets, the hostname, the port) is read at **boot** from `config/runtime.exs`, not at compile
time.

### Why hosting this is slightly unusual

All match state is **in memory on one machine**. That's fine for one server, but it has
consequences:

- A deploy restarts the VM and every in-progress match is lost. That's acceptable for a hobby
  arcade game. Deploy when nobody's playing.
- Running **two** instances behind a load balancer breaks things. Player A's WebSocket lands on
  server 1, player B's on server 2, and each server has its own Registry, so "QXKB" exists on only
  one of them. Run exactly **one** instance unless you do the clustering stretch below.

### WebSockets in production

- `check_origin`: Phoenix rejects WebSocket connections from origins other than your configured
  host. Make sure `PHX_HOST` is set correctly, or the game page loads but the socket never
  connects. That's a classic first-deploy bug, so check the browser console.
- Your host must support long-lived WebSocket connections. Most modern platforms do.

## Steps

### 1. Prepare the release

```sh
mix phx.gen.release            # adds rel/ overlays, a server script, a migrate stub (unused, no Ecto)
mix phx.gen.release --docker   # if your host deploys Dockerfiles
```

Read the generated `Dockerfile` (if any) and `config/runtime.exs`. Find where `SECRET_KEY_BASE`,
`PHX_HOST` and `PORT` are read.

Build and run it locally in prod mode:

```sh
export SECRET_KEY_BASE=$(mix phx.gen.secret)
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
PHX_HOST=localhost PHX_SERVER=true _build/prod/rel/combat/bin/combat start
```

Play a game against `http://localhost:4000` running the **release** before deploying anywhere.

### 2. Choose a host

Any host that runs a Docker image or an Elixir release and supports WebSockets will do. Fly.io
has first-class Phoenix support (`fly launch` detects Phoenix and wires up most of the above), but
Render, Railway, Gigalixir or a small VPS all work.

Pick a **region near you and your friends**. Latency is gameplay here.

Keep it to **one instance** (see above). On Fly, that means `fly scale count 1`.

### 3. Remote shell into production

One of the most delightful things about the BEAM: you can open an iex shell **inside the
running production system** (`bin/combat remote`, or `fly ssh console --pty -C "/app/bin/combat remote"`
on Fly). Try:

```elixir
Combat.Matches.list_ids()
DynamicSupervisor.count_children(Combat.MatchSupervisor)
:sys.get_state(Combat.Matches.whereis("QXKB"))
```

Be careful in here: this is the live system. The inspection tools from guide 14
(`Process.info/2`, `:sys.get_state/1`) all work here too. Avoid `:sys.trace/2` on a live match.

LiveDashboard is only mounted in development, so you can't see your guide 14 metrics in
production yet. Stretch goal 5 in guide 14 (a Prometheus reporter) is the usual way to get them.

## Checkpoint

Send a friend the URL and a room code, and beat them at tanks.

## Stretch goals: going distributed

These are big, but they're also where Elixir really shines:

1. **Clustering:** connect nodes with [`libcluster`](https://hexdocs.pm/libcluster) (or your
   host's DNS-based discovery). `Phoenix.PubSub` and `Phoenix.Presence` work across a cluster
   **with no code changes**. That's why we routed snapshots through PubSub and used Presence.
2. **Finding matches cluster-wide:** `Registry` is node-local. Options, from simplest to most
   involved:
   - `:global` registration via `{:via, :global, {:match, id}}` (built into Erlang, fine at small
     scale)
   - process groups with `:pg`
   - a library like Horde (a distributed Registry and DynamicSupervisor)
3. **Call routing:** with a cluster-wide name, `GenServer.call` to a match on another node
   *just works*, because message passing is location-transparent. Your channel on node A can talk
   to a game server on node B without any code change.

If you get this far, you'll have built a real-time, fault-tolerant, distributed multiplayer game.
Not bad for a "for fun" project.
