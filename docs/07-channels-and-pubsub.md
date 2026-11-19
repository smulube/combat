# 07 — Channels & PubSub

## Goal

A browser can connect over a WebSocket, join `"game:QXKB"`, be assigned a slot (`p1`/`p2`),
receive the arena once, send inputs, and receive snapshots 30 times a second. You'll test all of
it from ExUnit, before writing any client code.

## Concepts

### Socket vs. Channel

- A **socket** is one WebSocket connection from one browser tab. It's handled by
  `CombatWeb.UserSocket`, where you **authenticate** the connection (`connect/3`).
- A **channel** is a conversation about one **topic**, multiplexed over that socket. Each joined
  channel is its **own process** (a GenServer under the hood), so if one player's channel crashes,
  nothing else is affected.

```
browser tab ──WebSocket──► UserSocket (connect/3, id/1)
                              ├── GameChannel process for "game:QXKB"
                              └── (could join more topics on the same socket)
```

### Channel callbacks

| Callback | When | Typical return |
|---|---|---|
| `join(topic, params, socket)` | client calls `channel.join()` | `{:ok, reply, socket}` or `{:error, reason}` |
| `handle_in(event, payload, socket)` | client calls `channel.push(event, payload)` | `{:noreply, socket}` or `{:reply, {:ok, map}, socket}` |
| `handle_info(msg, socket)` | any Elixir message to the channel process | `{:noreply, socket}` |
| `terminate(reason, socket)` | leave or disconnect | ignored |

`socket.assigns` is per-channel-process state, like a GenServer's state. Use `assign/3` to add to
it.

### Getting snapshots to the client

The `GameServer` broadcasts `{:snapshot, map}` on `"match:<id>"` (guide 05). Each `GameChannel`
**subscribes** to that topic when it joins, receives the message in `handle_info/2`, and calls
`push(socket, "snapshot", map)`. The game core never learns that channels exist.

> Phoenix has a shortcut, `CombatWeb.Endpoint.broadcast/3`, which pushes straight to every channel
> on a topic without going through `handle_info` ("fastlaning"). It's more efficient, but it would
> make `lib/combat` call `CombatWeb`. We prefer the clean boundary. See the stretch goals.

### Identifying players with `Phoenix.Token`

WebSocket connections don't carry the browser session cookie the same way HTTP requests do, so
the usual pattern is:

1. On the HTTP request, give the browser a random **player id** stored in the session.
2. Sign it into a **token** with `Phoenix.Token.sign/3` and put it in a `<meta>` tag.
3. JS sends the token as a socket param, and `UserSocket.connect/3` verifies it with
   `Phoenix.Token.verify/4` and assigns `player_id`.

A signed token can't be forged without your `secret_key_base`. It isn't *encrypted*, but there's
nothing secret inside.

### Who is p1 and who is p2?

The **game server** decides, because it's the single source of truth for the match. Add a
`join/2` to the game server that assigns the first free slot to a player id. It's **idempotent**:
if the same player id joins again (a page refresh), it gets the same slot back.

## Steps

### 1. Player identity plug

Create `lib/combat_web/plugs/player_id.ex` (`CombatWeb.Plugs.PlayerId`), a **function plug** or
module plug with `init/1` and `call/2`:

- If `get_session(conn, :player_id)` is nil, generate one
  (`:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)`) and `put_session` it.
- `assign(conn, :player_token, Phoenix.Token.sign(conn, "player", player_id))`.

Add `plug CombatWeb.Plugs.PlayerId` to the `:browser` pipeline in the router. In the root layout
(`lib/combat_web/components/layouts/root.html.heex`), add
`<meta name="player-token" content={assigns[:player_token]} />`.

### 2. Generate the socket and channel

Phoenix generators are fine here. They're scaffolding, and you'll rewrite the insides:

```sh
mix phx.gen.socket User
mix phx.gen.channel Game
```

Read what they printed. You must add the `socket "/socket", CombatWeb.UserSocket, ...` line to
`endpoint.ex` yourself, plus a `channel "game:*", CombatWeb.GameChannel` line in `UserSocket`.
Look at the generated files: `user_socket.ex`, `game_channel.ex`,
`test/combat_web/channels/game_channel_test.exs`, `test/support/channel_case.ex` and
`assets/js/user_socket.js`. Don't import `user_socket.js` from `app.js`. Guide 08 writes its own
socket code, and you can delete that file.

### 3. `UserSocket.connect/3`

- Verify `params["token"]` with
  `Phoenix.Token.verify(socket, "player", token, max_age: 86_400)`.
- On `{:ok, player_id}`, assign it and return `{:ok, socket}`. Otherwise return `:error`, which
  rejects the connection.
- `id/1` can return `"player_socket:#{player_id}"`. It lets you disconnect a player from
  anywhere by broadcasting `"disconnect"` to that id.

### 4. Slots in the game server

Extend the `GameServer` state with `players: %{}` (`slot => player_id`). Add:

- `GameServer.join(server, player_id) :: {:ok, slot} | {:error, :full}` as a **call**. Rules:
  - if `player_id` already has a slot, return it
  - otherwise take `:p1` if free, else `:p2`, else return `{:error, :full}`
- `Combat.Matches.join(id, player_id)` delegates and maps a missing match to
  `{:error, :not_found}`.

(Auto-starting the game when both slots fill, and freeing slots when players leave, come in
guides 09 and 13.)

### 5. `GameChannel`

**`join("game:" <> match_id, _params, socket)`:**

1. `Combat.Matches.join(match_id, socket.assigns.player_id)`. On error, return
   `{:error, %{reason: "not_found" | "full"}}`.
2. `Phoenix.PubSub.subscribe(Combat.PubSub, Combat.GameServer.topic(match_id))`.
3. Assign `match_id` and `slot`.
4. Reply with everything the client needs once:
   `%{slot: "p1", arena: arena_info}`.

**`handle_in("input", payload, socket)`:**

- `Input.from_params(payload)` (guide 02 made this safe against hostile input), then
  `Matches.set_input(match_id, slot, input)`, then `{:noreply, socket}`.
- The slot comes from **`socket.assigns`**, never from the payload. A client must not be able to
  say "I'm p2".

**`handle_info({:snapshot, snap}, socket)`:** `push(socket, "snapshot", snap)`, then
`{:noreply, socket}`.

**Temporary:** until the lobby exists (guide 09), add a `handle_in("start", _, socket)` that calls
`Matches.start_game/1`, so you can start a match from the browser console.

<details><summary>Hint: subscribe before or after join?</summary>

Subscribing *before* the join call succeeds means you might start receiving snapshots for a match
you then fail to join. In that case the channel process exits anyway, so it's harmless, but
"subscribe after success" is the tidier habit.
</details>

### 6. Make `/play/:id` create matches for now

Temporarily, in `GameController.show/2`: if the match doesn't exist, start it with that exact id.
Add a `Combat.Matches.ensure_started(id)` for this (start with the given id and treat
`:already_started` as success). The lobby in guide 09 replaces this.

## Tests (`test/combat_web/channels/game_channel_test.exs`)

`CombatWeb.ChannelCase` gives you `socket/3`, `subscribe_and_join/3`, `push/3`, `assert_push/3`
and `assert_reply/3`. Each test:

- create a match in `setup`, stop it in `on_exit`
- build a socket with `socket(CombatWeb.UserSocket, "player_socket:a", %{player_id: "a"})`.
  That skips `connect/3`, which you can test separately.

Tests to write:

- Joining returns `slot: "p1"` and an arena with walls.
- A second player gets `"p2"`, and a third gets `{:error, %{reason: "full"}}`.
- The same player id joining twice gets the same slot.
- Joining `"game:NOPE"` fails with `"not_found"`.
- After `start` and `push(socket, "input", %{"forward" => true})`, sending the GameServer `:tick`
  (create the match with `tick_ms: :manual`) leads to `assert_push "snapshot", %{tanks: tanks}`.
  The `p1` tank has moved.
- `UserSocket.connect/3` rejects a garbage token and accepts a token you signed in the test with
  `Phoenix.Token.sign(CombatWeb.Endpoint, "player", "a")`.

## Checkpoint

All channel tests pass. That's the real checkpoint: you've proven the whole server side, from
WebSocket message to game state and back, without a browser.

Also visit `/play/TEST` in a browser and confirm in the page source that the `player-token` meta
tag is filled in. Then, in `iex -S mix phx.server`, run `Combat.Matches.list_ids()` to see that
the page created match `"TEST"`.

## Stretch goals

- Switch to fastlaning: give `GameServer` a `:broadcast_fun` option that defaults to
  `&Phoenix.PubSub.broadcast/3`, and in production pass a function that calls
  `CombatWeb.Endpoint.broadcast/3` on the `"game:"` topic. That keeps the core independent while
  getting the performance. Measure whether it matters (it won't at two players per match).
- Handle `"input"` floods: drop inputs if a client sends more than ~60/s (a token bucket in
  `socket.assigns`).

Next: [08 — Canvas client](08-canvas-client.md)
