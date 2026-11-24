# 03 — Movement & collision

## Goal

`Combat.Game.tick(state, dt)` moves both tanks according to their inputs: they rotate in clicky
16-way steps, drive forwards and backwards, and stop at (or slide along) walls and each other.
Arenas can be drawn as ASCII art.

## Concepts

### The shape of an update function

Every update in the core has this shape:

```
old_data, inputs, dt  ──►  new_data
```

No side effects and no hidden state. A whole tick is a pipeline of such functions:

```elixir
state
|> apply_movement(dt)
|> ... more steps in later guides
```

Each step takes a `%State{}` and returns a `%State{}`, which is why the pipe operator reads so
nicely here. If a step only cares about tanks, it still takes and returns the whole state. Inside
it, `Map.new/2` or `Map.update!/3` over `state.tanks` does the work.

### Variable timestep vs. fixed timestep

Passing `dt` in explicitly means the core doesn't care how often it's called. Guide 05 calls it
with a fixed `dt`, and tests can call it with whatever they like. Tests can simulate a whole
second of play instantly by calling `tick/2` thirty times.

### AABB collision

Two axis-aligned rectangles `a` and `b` overlap when **all four** are true:

```
a.x < b.x + b.w    and    a.x + a.w > b.x
a.y < b.y + b.h    and    a.y + a.h > b.y
```

Strict `<` means rectangles that merely touch edges don't count as overlapping. That's what lets a
tank sit flush against a wall and still move along it.

### Sliding along walls (axis separation)

If you just cancel the whole move when a tank would overlap a wall, tanks feel "sticky" whenever
they touch a wall at an angle. The classic fix:

1. Try the full move `{dx, dy}`. If it's clear, take it.
2. Otherwise try `{dx, 0}` alone. If it's clear, take it.
3. Otherwise try `{0, dy}` alone. If it's clear, take it.
4. Otherwise don't move.

Each attempt is **all or nothing**: a blocked move is cancelled, not shortened. Axis separation
only helps when the move is diagonal, because then one axis can still go through. Driving
straight at a wall, the tank stops wherever it is when the next full step would overlap, which
leaves a gap of up to one tick's movement (about 1 unit at 30 Hz). That gap never closes, since
every later step is blocked too. It's barely visible, so we accept it. Closing it is a stretch
goal.

## Steps

### 1. `Combat.Game.Collision` (`lib/combat/game/collision.ex`)

- `overlaps?(a, b) :: boolean` takes two `%{x, y, w, h}` maps.
- `any_overlap?(rect, rects) :: boolean` uses `Enum.any?/2`.
- `contains_point?(rect, {x, y}) :: boolean`, which you'll need for shells in guide 04.

### 2. Input in the core

Add `Combat.Game.set_input(state, slot, %Input{}) :: State.t()`. It just stores the input in
`state.inputs`. It should raise `FunctionClauseError` for an unknown slot. Pattern-match
`slot when slot in [:p1, :p2]` in the function head.

Add `Combat.Game.start(state)`, which sets `status: :playing`.

### 3. `Combat.Game.Movement` (`lib/combat/game/movement.ex`)

```elixir
@spec move_tank(tank :: Tank.t(), input :: Input.t(), dt :: float(), obstacles :: [rect]) ::
        Tank.t()
```

The arguments, in order:

- `tank`: the tank being moved.
- `input`: the buttons that tank's player is holding (`%Input{}`).
- `dt`: seconds since the last tick, the same `dt` that `tick/2` receives. Cooldowns count down
  by it, and displacement scales with it.
- `obstacles`: the list of `%{x, y, w, h}` rects the tank must not overlap. That's the arena
  walls **plus the other tank's bounds**. `rect` here means the same rect type that `Collision`
  works with. If you gave it a name in guide 02 (for example `Arena.rect()`), use that.

Behaviour, in order:

1. **Cooldowns:** subtract `dt` from `turn_cooldown`, flooring at `0.0`.
2. **Rotation:** if `turn_cooldown` is `0.0` and exactly one of `left`/`right` is held, rotate one
   step (`left` = `-1`, anticlockwise on screen) and reset `turn_cooldown` to the turn interval.
   Holding both does nothing.
3. **Translation:** `forward` moves along `Vec.from_dir(dir)` at full speed. `back` moves the
   opposite way at **half** speed. Holding both does nothing. The displacement is
   `direction × speed × dt`.
4. **Collision:** resolve with the axis-separation algorithm above, using `Tank.bounds/1` on the
   *proposed* tank.

<details><summary>Hint: structuring <code>move_tank/4</code></summary>

Each of the four behaviours above is its own small transformation. Give each one a private
helper that takes a tank and returns a tank, then make `move_tank/4` a pipeline:

```elixir
tank
|> tick_cooldowns(dt)
|> rotate(input)
|> translate(input, dt, obstacles)
```

Collision belongs inside `translate`, because it decides whether the translation happens.

- **Turn the input into a number first.** Both `rotate` and `translate` are easier if you turn
  two booleans into one value before doing any maths. Pattern-match on a tuple, for example
  `case {input.left, input.right} do ... end`, to get a turn step of `-1`, `0` or `1`, or a
  speed factor of `1.0`, `-0.5` or `0.0` from `forward`/`back`. "Holding both does nothing"
  then becomes a single clause.
- **Guard clauses for "nothing happens".** `rotate` has two cases where nothing happens:
  the cooldown is still running, or the turn step is `0`. A function head with a guard
  (`when cooldown > 0.0`) that returns the tank unchanged is often clearer than a nested `if`.
- **Stay in floats.** `max(x, 0)` returns the *integer* `0` when it wins. Compare with `0.0`
  so the field keeps the type its typespec promises.
- **Update the struct with `%{tank | field: value}`.** Each helper returns the tank with one or
  two fields changed.

Test each behaviour on its own: a tank with `turn_cooldown: 0.0` and `left: true` should end
up with `dir` one step anticlockwise, and so on.
</details>

<details><summary>Hint: a tidy way to write the slide</summary>

Write a small private helper `try_move(tank, {dx, dy}, obstacles) :: {:ok, tank} | :blocked`,
then chain the three attempts with `with` / `else`, or with a `Enum.find_value/2` over the list
`[{dx, dy}, {dx, 0.0}, {0.0, dy}]`. The second version is short and readable.
</details>

### 4. Wire it into `Combat.Game.tick/2`

```elixir
@spec tick(State.t(), float()) :: State.t()
```

- If `status != :playing`, return the state unchanged. Use a separate function clause rather than
  an `if`.
- Otherwise run the pipeline. For now there's one step, `move_tanks/2`. It updates each tank with
  its own input, and the obstacles are the walls plus the *other* tank's bounds.

Think about fairness: if `p1` moves first and then `p2` checks against `p1`'s *new* position, `p1`
has a tiny advantage when they collide. At this scale nobody will notice, but write a comment
about it. (One fix is to check both against the *old* positions, then undo both moves if the new
positions overlap.)

### 5. Arenas as ASCII art

Writing wall coordinates by hand is miserable. Instead, describe an arena as a grid of
characters, where each character is a **10 × 10** cell (so 16 columns × 10 rows = 160 × 100):

```
################
#..............#
#..1...##...2..#
#......##......#
#..##......##..#
#..##......##..#
#......##......#
#......##......#
#..............#
################
```

- `#` is a wall cell.
- `.` is empty.
- `1` / `2` are spawn cells. The tank spawns at the cell's centre, `p1` facing east and `p2`
  facing west.

(That's an example layout. Design your own mazes!)

In `Combat.Game.Arenas`:

- `from_ascii(string) :: Arena.t()` does the parsing. Use `String.split/2` on newlines,
  `String.graphemes/1`, and `Enum.with_index/1` twice to get `{char, col, row}` triples. Then:
  - each `#` becomes a wall `%{x: col * 10, y: row * 10, w: 10, h: 10}`
  - `1` and `2` become the spawns
- Rewrite `open_field/0` to use it, and add `maze/0` with your own design.
- Use the **compile-time trick** from guide 02: `@maze from_ascii(...)` would parse at compile
  time, but you can't call a function from the *same* module in a module attribute. Either parse
  in the function body (simple, and plenty fast), or move `from_ascii/1` into a separate
  `Combat.Game.ArenaParser` module. Try the second option to see the compile error first.

<details><summary>Hint: fewer walls with run-length merging (optional)</summary>

A full border alone is 52 cells, which means 52 rects to check per move. You can merge horizontal
runs of `#` in the same row into one wide rect. Walk each row with `Enum.chunk_by/2` on the
character, keep the `#` chunks, and emit one rect per chunk. That cuts the wall count by roughly
5×, and the snapshot (guide 07) gets smaller too.
</details>

## Tests

In `test/combat/game/movement_test.exs` and `test/combat/game/collision_test.exs`:

- `overlaps?/2` is false for rects that only touch edges, and true for a 0.1 overlap.
- A tank holding `forward` facing east for 1 second (30 ticks of `1/30`) moves about 30 units in
  `x` when nothing is in the way.
- A tank driving straight into a wall stops flush against it and never overlaps it. Check
  `any_overlap?` after every tick.
- A tank driving diagonally (dir 2) into a horizontal wall keeps moving along `x`, which proves
  sliding works.
- Holding `left` for 0.5 s rotates exactly `floor(0.5 / turn_interval)`-ish steps. Pick numbers
  that avoid floating-point edge cases, or assert a range.
- `Game.tick/2` does nothing while `:waiting`.
- `Arenas.from_ascii/1` on a 3×3 string gives the expected walls and spawns.

<details><summary>Hint: a helper for "run N ticks"</summary>

In your test module:

```elixir
defp run(state, ticks, dt \\ 1 / 30), do: Enum.reduce(1..ticks, state, fn _, s -> Game.tick(s, dt) end)
```

You'll copy this into a shared `test/support/game_helpers.ex` later. That folder is already in the
test `elixirc_paths` in `mix.exs`. Check!
</details>

## Checkpoint

`mix test` is green. In iex:

```elixir
alias Combat.Game
alias Combat.Game.{Arenas, Input}
s = Arenas.maze() |> Game.new() |> Game.start() |> Game.set_input(:p1, %Input{forward: true})
s = Enum.reduce(1..60, s, fn _, s -> Game.tick(s, 1/30) end)
s.tanks.p1.pos
```

The tank has moved and is not inside a wall.

## Stretch goals

- Write a **property-based test** with [`stream_data`](https://hexdocs.pm/stream_data): for *any*
  random sequence of inputs, a tank never overlaps a wall. This is the single best test in the
  whole project and catches real bugs.
- Make tanks collide with each other using a slightly smaller box, so that squeezing past each
  other is forgiving.
- Close the gap in front of walls. When a move along an axis is blocked, move the tank exactly up
  to the nearest obstacle instead of not moving at all. Work out the distance from the tank's
  leading edge to the obstacle's facing edge. Remember that edges which merely touch don't count
  as overlapping, so a tank flush against a wall is allowed. Test that a tank driven at a wall
  for many ticks ends up exactly touching it.

Next: [04 — Shells, hits & scoring](04-shells-hits-and-scoring.md)
