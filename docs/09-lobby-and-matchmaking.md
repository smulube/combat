# 09 — Lobby & matchmaking

## Goal

There's a proper flow: home page → "New match" (get a room code to share) or "Join" (type a
code) → a waiting room that shows who's connected → an automatic 3-2-1 countdown when both
players are present → the game → a "Rematch?" button. The temporary Start button and auto-create
hack go away.

## Concepts

### Phoenix.Presence

Presence answers "who is currently connected to this topic?" across the whole system, even across
multiple servers. You `track` a process under a key with some metadata. When that process dies
(the tab closes), its entry disappears automatically and everyone on the topic is told.

It's built on a **CRDT** (conflict-free replicated data type) that nodes gossip about, so it's
*eventually consistent*. That makes it perfect for UI ("Opponent connected ✔"), but **not** the
source of truth for game rules. The `GameServer` still owns the slots.

The JS side has a matching `Presence` class that merges the initial `"presence_state"` and the
incremental `"presence_diff"` messages for you, and calls `onSync` when the list changes.

### The `:after_join` pattern

You can't `push` from inside `join/3`, because the client hasn't finished joining yet. The idiom is
`send(self(), :after_join)` in `join/3`, then do the pushing and tracking in
`handle_info(:after_join, socket)`. That message is handled immediately after the join completes.

### Countdown as game state

"3-2-1-GO" is part of the game, so it belongs in the **core** as a status, not as a JS timer.
That way both clients show exactly the same number and nobody gets a head start.

## Steps

### 1. Countdown in the core

- `State.status` gains `:countdown`, so the flow is now `:waiting → :countdown → :playing → :over`.
- Add the field `countdown: 0.0`.
- `Game.begin_countdown(state, seconds \\ 3.0)` sets the status and the time.
- `tick/2` while in `:countdown`: decrement it, and switch to `:playing` at zero. Inputs are
  ignored during the countdown. Decide whether tanks can rotate in place: it's a nice touch.
- The snapshot includes `countdown` (rounded **up** to an integer for display, `ceil/1`).
- `Game.reset(state)` returns a fresh game on the same arena, keeping nothing but the arena.
  Use it for rematches.

Write the tests first: the countdown reaches `:playing` after 3 s of ticks, and input is ignored
until then.

### 2. Auto-start in the GameServer

- In `join/2`: after assigning a slot, if **both slots are filled** and the game is `:waiting`,
  call `Game.begin_countdown/1`.
- Remove the temporary `start` path: the channel's `handle_in("start", ...)` and the JS button.
  (Keep `Matches.start_game/1` if your tests use it.)

### 3. Rematch

- `GameServer.request_rematch(server, slot)` (cast). Store requests in a `MapSet` in the server
  state. When both slots have requested and the game is `:over`, `Game.reset/1` then
  `Game.begin_countdown/1`, and clear the set.
- Include `rematch: ["p1"]` (who has asked) in the snapshot. This is server-shell data rather than
  core data, so merge it into the map in the GameServer before broadcasting.
- Channel: `handle_in("rematch", _, socket)`.
- Client: when `status === "over"`, show a Rematch button and "Opponent wants a rematch!" when
  appropriate.

### 4. Home page lobby

Replace `page_html/home.html.heex` with two forms:

- **New match**: `POST /matches`. `MatchController.create/2` calls `Matches.create_match()`
  and `redirect(conn, to: ~p"/play/#{id}")`.
- **Join**: a text input named `code`, submitting `GET /join`. `MatchController.join/2` upcases
  and trims the code, then redirects to `/play/CODE`.

Use Phoenix's `<.form>` and `<.input>` core components (look in `core_components.ex`), and
`~p` **verified routes**: `~p"/play/#{id}"` is checked against the router at compile time, so a
typo in a path is a compiler warning rather than a 404.

In `GameController.show/2`: if `Matches.exists?(id)` is false, `put_flash(:error, "No match
with code #{id}")` and redirect home. Delete the `ensure_started` hack from guide 07.

On the game page, show the code prominently, with a "copy link" button using
`navigator.clipboard.writeText(location.href)`.

### 5. Presence

```sh
mix phx.gen.presence
```

Add `CombatWeb.Presence` to `application.ex` **after** `Phoenix.PubSub` (it depends on it) and
**before** the endpoint.

In `GameChannel`:

- In `join/3`, add `send(self(), :after_join)` before returning.
- In `handle_info(:after_join, socket)`:
  - `Presence.track(socket, socket.assigns.player_id, %{slot: "p1"})`
  - `push(socket, "presence_state", Presence.list(socket))`

Presence tracks on the **channel topic** (`"game:QXKB"`), and Phoenix sends
`"presence_diff"` messages automatically.

Client (`assets/js/game/lobby.js`, or inside `index.js`):

```js
import { Presence } from "phoenix"
const presence = new Presence(channel)
presence.onSync(() => { /* presence.list(...) → update the waiting room UI */ })
```

The waiting room UI: "You are Player 1 (green)", "Waiting for opponent… share code QXKB" →
"Opponent connected", then the countdown digits drawn big over the canvas, or as a DOM overlay.

<details><summary>Hint: what does <code>Presence.list/1</code> return?</summary>

A map keyed by your `track` key (the player id), each value being `%{metas: [meta, ...]}`.
There's a *list* of metas because the same key can be tracked several times, for example the same
player in two tabs. Inspect it in a test with `IO.inspect` before writing the JS.
</details>

## Tests

- Core: the countdown tests above, plus `reset/1`.
- GameServer: joining two different players moves the status to `:countdown`, and two rematch
  requests after `:over` give a new `:countdown` with scores at zero. To reach `:over` quickly,
  start a server with a short round. Add a `:round_seconds` option to `GameServer.start_link/1`
  and pass it down to `Game.new/2`.
- Controller (`test/combat_web/controllers/match_controller_test.exs`, using `ConnCase`):
  `POST /matches` redirects to `/play/XXXX`, and that match exists. `GET /play/NOPE` redirects
  home with a flash.
- Channel: after joining, `assert_push "presence_state", _`.

## Checkpoint

1. Window A: home page → New match. You're in a waiting room with a code.
2. Window B (private window): home page → type the code → Join.
3. Both see "Opponent connected", then 3-2-1, and play.
4. Wait out the timer (or temporarily make rounds 15 s long) → Rematch in both → a new round.
5. Close window B mid-game. Window A's Presence list updates within a second. (What should the
   *game* do about it? That's guide 13.)

## Stretch goals

- **Quick match:** a "Play anyone" button. A `Combat.Matchmaker` GenServer keeps a queue of
  waiting player ids. When two are queued, it creates a match and tells both. That's a good
  exercise in `GenServer.reply/2`: let the `call` from the first player stay open until a partner
  arrives. Return `{:noreply, state}` from `handle_call` and keep the `from` around.
- **Spectators:** a third player joining gets a `:spectator` role. It receives snapshots but its
  inputs are ignored.
- Use the registry metadata from guide 06 to list open matches on the home page.

Next: [10 — Game modes behaviour](10-game-modes-behaviour.md)
