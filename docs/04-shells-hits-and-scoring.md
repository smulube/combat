# 04 — Shells, hits & scoring

## Goal

Tanks fire shells, shells fly and disappear on walls, and hitting the enemy scores a point and
spins them out. The round timer runs down and the game ends with a winner. You'll also write
`Combat.Game.snapshot/1`, the JSON-friendly view of the state that the network layer will send.

When you finish this guide, the **entire single-mode game exists as pure functions.**

## Concepts

### A tick as an ordered pipeline

Order matters. Here's the order we'll use, with the reason for each position:

```elixir
state
|> clear_events()          # start each tick with an empty event list
|> move_tanks(dt)          # guide 03
|> fire_shells()           # new shells appear at the muzzle using this tick's tank positions
|> move_shells(dt)
|> resolve_shell_walls()   # shells that hit walls vanish
|> resolve_shell_hits()    # shells that hit tanks score
|> expire_shells(dt)       # ttl runs out
|> tick_clock(dt)          # may flip status to :over
```

Try reordering steps once things work and think about what changes. For example, what happens if
`fire_shells` runs *after* `move_shells`?

### Events

Some things happen *at an instant* rather than being *state*: a shot was fired, a tank was hit.
The client wants to know about them to play sounds or flash the screen, but they aren't things to
draw every frame. Collect them in a list in the state (`events`), clear it at the start of every
tick, and include it in the snapshot. Each event is a small map like
`%{type: :hit, victim: :p2}`.

### Snapshots vs. state

The `State` struct is the **server's** truth: inputs, cooldowns, counters, the whole arena.
A **snapshot** is the minimum the **client** needs to draw one frame:

- only plain maps, lists, strings and numbers, so it encodes straight to JSON
- floats rounded to 1–2 decimals, because nobody can see 0.0001 of a unit and smaller JSON is
  faster JSON
- no static data. The arena never changes during a match, so it's sent **once** when a player
  joins, not 30 times a second

## Steps

### 1. Extend the structs

- `Shell`: add `@speed 80.0` and `@lifetime 1.5` (seconds) with accessor functions.
- `Tank`: add `@reload_time 0.5` and `@spin_time 1.0`.
- `State`: add `events: []`.

### 2. Firing: `fire_shells/1` (private in `Combat.Game`, or a new `Combat.Game.Weapons` module)

A tank fires when **all** of these hold:

- its input has `fire: true`
- `reload == 0.0`
- `spin == 0.0` (a spinning tank can't fire)
- it has **no shell currently alive.** This is the original game's famous one-shell-at-a-time
  rule, and it's what makes aiming matter

Firing:

- creates a `%Shell{}` with `id: state.next_id`, `owner: tank.id`
- places it at the muzzle, `tank.pos + from_dir(dir) × (tank size / 2 + 1)`, so it can't hit
  its own tank on the first tick
- sets `vel = from_dir(dir) × shell speed` and `ttl = lifetime`
- sets the tank's `reload` to `reload_time` and increments `next_id`
- appends `%{type: :fire, by: tank.id}` to `events`

Don't forget: `reload` must count down somewhere. `Movement.move_tank/4` already handles
`turn_cooldown`, so add `reload` (and `spin`) to the same cooldown step.

<details><summary>Hint: reducing over the two tanks while updating several fields</summary>

Firing changes `tanks`, `shells`, `next_id` and `events` together, so a simple `Map.new` over the
tanks won't do. `Enum.reduce(Map.keys(state.tanks), state, fn slot, acc -> maybe_fire(acc, slot) end)`
threads the whole state through, letting each `maybe_fire/2` return an updated state.
</details>

### 3. Shell movement and walls

- `move_shells/2`: `pos = pos + vel × dt`.
- `resolve_shell_walls/1`: drop any shell whose position is inside any wall
  (`Collision.contains_point?/2`).

Tunnelling check: a shell moving 80 u/s at 30 ticks/s travels ~2.7 units per tick. Walls are 10
thick (border walls 2), so a shell can't skip through a wall in one step. If you ever make shells
much faster, you'd need to test the *segment* the shell travelled, not just its end point. Write
that down in a comment.

### 4. Hits: `resolve_shell_hits/1`

For each shell, check the **other** player's tank: does `Tank.bounds/1` contain the shell's
position?

On a hit:

- remove the shell
- `scores[owner] += 1`
- set the victim's `spin` to `spin_time`
- add the event `%{type: :hit, victim: victim_id, by: owner}`

A tank that's **already spinning can't be hit again.** Shells pass straight over it. Without this
rule, one burst could score several points.

### 5. Spin-out behaviour

Change `Movement.move_tank/4` so that while `spin > 0`:

- input is ignored completely
- the tank rotates one step every `0.05` s, whatever the input (use the same
  `turn_cooldown` field)
- it doesn't translate

(The original also shoved the tank backwards. Add that as a stretch goal: store the hit shell's
velocity on the tank as `knockback`, apply it during spin with friction, and respect walls.)

### 6. Expiry and the clock

- `expire_shells/2`: subtract `dt` from each `ttl`, and drop shells at `<= 0`.
- `tick_clock/2`: subtract `dt` from `time_left`. When it reaches `<= 0`, clamp it to `0.0`, set
  `status: :over`, set `winner` (`:p1`, `:p2` or `:draw`), and add the event `%{type: :game_over}`.

### 7. `Combat.Game.snapshot/1` and `Combat.Game.arena_info/1`

`snapshot(state) :: map()` returns exactly this shape. Keep it stable, because the JavaScript in
guide 08 depends on it:

```elixir
%{
  status: "playing",                 # Atom.to_string(state.status)
  time_left: 121.4,                  # rounded to 1 decimal
  scores: %{p1: 3, p2: 1},
  winner: nil,                       # or "p1" / "p2" / "draw"
  tanks: [
    %{id: "p1", x: 31.25, y: 50.0, dir: 3, spinning: false},
    %{id: "p2", x: 128.0, y: 50.0, dir: 8, spinning: true}
  ],
  shells: [%{id: 7, x: 70.12, y: 44.5}],
  events: [%{type: "hit", victim: "p2", by: "p1"}]
}
```

`arena_info(state) :: map()` returns `%{width:, height:, walls: [...]}`. It's sent once on join.

<details><summary>Hint: rounding</summary>

`Float.round(x, 2)` needs a float. If `x` might be an integer (e.g. `50`), use `x / 1` or
`x * 1.0` first. Alternatively make sure positions are always floats when created. Spawns parsed
from ASCII art are the usual culprit.
</details>

## Tests

Put shared builders in `test/support/game_helpers.ex` (`Combat.GameHelpers`): `playing_state/1`,
`run/3`, `place_tank/4` (put a tank at a position and direction). Then test:

- Holding `fire` creates exactly **one** shell. Holding it for 2 seconds while the shell flies
  into a wall creates more, but never two alive at once.
- A shell fired at the enemy from 30 units away hits within ~0.5 s: the score goes to 1, the
  victim has `spin > 0`, and the events contain a `:hit`.
- A spinning tank can't be hit again (fire twice quickly at a stationary target).
- A spinning tank ignores `forward`.
- Shells vanish on walls and expire after their lifetime in open space.
- Running a fresh `:playing` state for 137 seconds of ticks ends with `status: :over` and
  `winner: :draw`.
- `snapshot/1` output survives `Jason.encode!/1`. (`Jason` comes with Phoenix. You can also use
  Elixir's built-in `JSON.encode!/1`, so try both.)

## Checkpoint

`mix test` is green, and this iex experiment produces a hit:

```elixir
s = Combat.Game.Arenas.open_field() |> Combat.Game.new() |> Combat.Game.start()
s = Combat.Game.set_input(s, :p1, %Combat.Game.Input{fire: true})
s = Enum.reduce(1..90, s, fn _, s -> Combat.Game.tick(s, 1/30) end)
{s.scores, Combat.Game.snapshot(s)}
```

(With spawns at left-middle facing east and right-middle facing west, `p1` shoots straight at
`p2`.)

## Stretch goals

- **Ricochet variant:** shells bounce off walls a limited number of times. Work out which face was
  hit by comparing the shell's previous position to the wall's edges, then flip `vx` or `vy`.
- **Guided missiles variant:** while `fire` is held, the shell's direction follows the tank's
  `left`/`right` input.
- A first-to-N-points win condition alongside the timer.

Next: [05 — The GenServer](05-game-server.md)
