# 02 — Game core: data model

## Goal

Define the data that describes a match, plus the small helpers everything else builds on. By the
end, `Combat.Game.new/1` returns a fully populated state with two tanks at their spawn points, and
you have your first passing tests.

There are **no processes in this guide.** All of it is plain data and pure functions.

## Concepts

### Why structs and not plain maps?

Structs give you compile-time key checking (`%Tank{speeed: 1}` won't compile), default values, and
a name to pattern-match on (`%Tank{} = tank`). Use `@enforce_keys` for fields that must always be
given and have no sensible default.

### Typespecs

Write a `@type t :: %__MODULE__{...}` for every struct. The compiler only lightly checks these
(Elixir 1.18+ does some type inference of its own), but they're superb documentation, and later
guides refer to `State.t()` and `Tank.t()`.

### Compile-time module attributes

A module attribute like `@foo some_expression` is evaluated **once, at compile time**, and the
result is baked into the bytecode. That's perfect for lookup tables. We'll precompute the 16
direction vectors this way, so the game never calls `:math.cos/1` at runtime.

### Why 16 directions?

The original hardware could only draw a handful of tank sprites, so tanks rotated in 16 discrete
steps (22.5° each). We keep that, for three reasons:

- It feels authentic. Turning is "clicky" rather than smooth.
- Direction becomes a small integer (`0..15`), which is trivial to send over the wire and to
  compare in tests.
- The client can later draw a pre-made sprite per direction instead of rotating images.

## Steps

All core modules live under `lib/combat/game/`, and tests under `test/combat/game/`.

### 1. `Combat.Game.Vec` (`lib/combat/game/vec.ex`)

Vectors are 2-tuples of floats: `{x, y}`.

| Function | Spec | Behaviour |
|---|---|---|
| `add/2` | `(v, v) :: v` | Component-wise sum |
| `sub/2` | `(v, v) :: v` | Component-wise difference |
| `scale/2` | `(v, number) :: v` | Multiply both components |
| `length/1` | `(v) :: float` | Euclidean length |
| `from_dir/1` | `(0..15) :: v` | Unit vector for a direction index |
| `rotate_dir/2` | `(dir, delta) :: 0..15` | `dir + delta` wrapped into `0..15` (use `Integer.mod/2`, not `rem/2`; try both with `-1` and see why) |

Direction convention: **`0` points right (east)**, and indices increase **clockwise**. Because `y`
grows downwards, `4` points *down* (south), `8` left and `12` up. The angle is
`dir * 2π / 16`, and the vector is `{cos(angle), sin(angle)}`.

Build a module attribute `@unit_vectors` containing a **tuple** of 16 `{x, y}` pairs, built with a
`for` comprehension and `List.to_tuple/1`. `from_dir/1` is then just `elem(@unit_vectors, dir)`.

<details><summary>Hint: why a tuple and not a list?</summary>

`elem/2` on a tuple is O(1). `Enum.at/2` on a list is O(n). With 16 elements it hardly matters,
but it's a good habit for fixed-size lookup tables.
</details>

Add `@doc` examples and enable **doctests** (`doctest Combat.Game.Vec` in the test module). For
example, `from_dir(0)` returns `{1.0, 0.0}`.

### 2. `Combat.Game.Input` (`lib/combat/game/input.ex`)

What one player is currently holding down:

```
defstruct left: false, right: false, forward: false, back: false, fire: false
```

- `new/0` returns an all-false input.
- `from_params/1` takes a map with **string keys** (exactly what arrives from JSON, e.g.
  `%{"left" => true, "fire" => false}`) and returns an `%Input{}`. Rules:
  - Unknown keys are ignored. **Never** call `String.to_atom/1` on client data, because atoms
    are never garbage-collected, so a malicious client could exhaust the atom table.
  - Values that aren't `true` are treated as `false`.

### 3. `Combat.Game.Arena` (`lib/combat/game/arena.ex`)

| Field | Type | Meaning |
|---|---|---|
| `width` | number | 160 |
| `height` | number | 100 |
| `walls` | list of `%{x, y, w, h}` maps | Solid rectangles, top-left corner + size |
| `spawns` | `%{p1: {x, y, dir}, p2: {x, y, dir}}` | Where each side starts |

Walls are plain maps rather than structs so they encode to JSON with no extra work (guide 07).

Create `Combat.Game.Arenas` (`lib/combat/game/arenas.ex`) with one function for now,
`open_field/0`. It returns an arena with only the four **border walls** (each 2 units thick), plus
spawns at the left-middle facing east and the right-middle facing west.

### 4. `Combat.Game.Tank` (`lib/combat/game/tank.ex`)

| Field | Default | Meaning |
|---|---|---|
| `id` | (enforced) | `:p1` or `:p2` |
| `pos` | (enforced) | `{x, y}` **centre** of the tank |
| `dir` | `0` | Direction index `0..15` |
| `turn_cooldown` | `0.0` | Seconds until it may rotate another step |
| `reload` | `0.0` | Seconds until it may fire again |
| `spin` | `0.0` | Seconds of "spin-out" left after being hit (guide 04) |

Also define module attributes for tuning, with functions to read them:

- `@size 6.0`: tanks collide as a 6 × 6 square centred on `pos`. The hitbox doesn't rotate,
  which is a classic simplification you won't notice when playing.
- `@speed 30.0` units/second.
- `@turn_interval 0.08` seconds per rotation step.

Add `bounds(tank) :: %{x, y, w, h}` that returns the hitbox as a rect in the same shape as a wall.
That way one collision function handles everything.

### 5. `Combat.Game.Shell` (`lib/combat/game/shell.ex`)

| Field | Meaning |
|---|---|
| `id` | Integer, unique within a match (the client uses it to track shells across snapshots) |
| `owner` | `:p1` / `:p2` |
| `pos` | `{x, y}` |
| `vel` | `{vx, vy}` in units/second |
| `ttl` | Seconds left before it fizzles out |

### 6. `Combat.Game.State` (`lib/combat/game/state.ex`)

| Field | Default | Meaning |
|---|---|---|
| `arena` | (enforced) | `%Arena{}` |
| `tanks` | `%{}` | `%{p1: %Tank{}, p2: %Tank{}}` |
| `shells` | `[]` | List of `%Shell{}` |
| `inputs` | `%{p1: Input.new(), p2: Input.new()}` | Latest input per slot (see the hint) |
| `scores` | `%{p1: 0, p2: 0}` | |
| `time_left` | `136.0` | Seconds (2:16) |
| `status` | `:waiting` | `:waiting` → `:playing` → `:over` |
| `winner` | `nil` | `:p1`, `:p2`, `:draw` or `nil` |
| `next_id` | `1` | Counter for shell ids |

<details><summary>Hint: you can't call a function in a <code>defstruct</code> default... or can you?</summary>

You can: `defstruct` defaults are evaluated at compile time, like module attributes. A
call to `Input.new()` there runs once at compile time, and its result (a constant struct) becomes
the default. That's fine because the result is immutable data. It would **not** be fine for
something like `System.monotonic_time()`, which would freeze to the compile time.
</details>

### 7. `Combat.Game` (`lib/combat/game.ex`), the public API of the core

For now, one function:

- `new(arena) :: State.t()` builds a state with both tanks placed at the arena's spawns.

The core will grow a few more public functions over the next guides (`start/1`, `set_input/3`,
`tick/2`, `snapshot/1`). The rule is that **nothing outside `lib/combat/game*` reaches into
`State` fields directly.** The GenServer only calls `Combat.Game.*` functions. That keeps the
shell thin and the rules in one place.

### 8. Tests

Create `test/combat/game/vec_test.exs`, `input_test.exs` and `test/combat/game_test.exs`. Here's
one complete example to show the shape. Write the rest yourself.

```elixir
defmodule Combat.Game.VecTest do
  use ExUnit.Case, async: true
  alias Combat.Game.Vec
  doctest Combat.Game.Vec

  test "direction 4 points straight down (y grows downwards)" do
    {x, y} = Vec.from_dir(4)
    assert_in_delta x, 0.0, 1.0e-9
    assert_in_delta y, 1.0, 1.0e-9
  end
end
```

Tests to write (descriptions only):

- `rotate_dir(0, -1) == 15` and `rotate_dir(15, 1) == 0`.
- Every `from_dir/1` result has length ≈ 1.0. Loop over `0..15` inside one test.
- `Input.from_params/1` ignores unknown keys and treats `"yes"` as false.
- `Game.new(Arenas.open_field())` has two tanks at the spawn positions, `status == :waiting`
  and both scores at zero.

## Checkpoint

```sh
mix test
```

All green. Then in `iex -S mix`:

```elixir
iex> Combat.Game.new(Combat.Game.Arenas.open_field())
```

Read the printed struct and make sure it looks like the match you imagine.

## Stretch goals

- Implement the `Inspect` protocol for `State` (`@derive {Inspect, only: [...]}`) so iex output
  hides the bulky `arena` field.
- Add a `Vec.dot/2` and `Vec.normalize/1`. You'll want them for biplanes.

Next: [03 — Movement & collision](03-movement-and-collision.md)
