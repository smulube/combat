# 10 — Game modes behaviour

## Goal

Make the game core mode-agnostic. The rules that differ between Tank, Biplane and Jet move behind
a **behaviour**, `Combat.Game.Mode`, and the existing tank game becomes `Combat.Game.Modes.Tank`.
At the end everything plays exactly as before, plus the lobby lets you pick a mode. (Only Tank
exists until guide 11.)

This is a **refactor**: behaviour stays the same and the structure changes. Your test suite from
guides 02–09 is the safety net, so keep it green after every step.

## Concepts

### Behaviours

A behaviour is a named list of functions a module promises to implement. You've already used two:
`GenServer` and `Plug`. Defining your own:

```elixir
defmodule Combat.Game.Mode do
  @callback name() :: String.t()
  @callback wrap?() :: boolean()
  # ...
end
```

An implementation declares `@behaviour Combat.Game.Mode` and marks each implementation with
`@impl true`. The compiler then warns you about missing callbacks, or about an `@impl` on
something that isn't a callback.

The core calls the mode *dynamically*: `state.mode.wrap?()`, where `state.mode` is a module atom
stored in the state. Modules are just atoms, so storing one in a struct is perfectly normal.

### Default implementations with `__using__`

Some callbacks have an obvious default (most modes don't hide units in clouds). Provide defaults
with a `__using__/1` macro, and let modes override them:

```elixir
defmacro __using__(_opts) do
  quote do
    @behaviour Combat.Game.Mode
    @impl true
    def visible?(_unit, _state), do: true
    defoverridable visible?: 2
  end
end
```

Then a mode writes `use Combat.Game.Mode` and only defines `visible?/2` if it needs something
different. That's the same mechanism `use GenServer` uses to give you a default `child_spec/1`.
Keep macros to this kind of boilerplate. Everything else should stay plain functions.

### Tank → Unit

Jets need several units per side, and "tank" is the wrong word for a plane. So:

- `Tank` → **`Unit`**, with a numeric `id` and a separate `side` (`:p1`/`:p2`).
- `state.tanks` (a map keyed by slot) → **`state.units`** (a map keyed by unit id).
- Shells get `side` (for scoring) and `shooter` (the unit id, for the one-shell-per-unit rule).
- Input still belongs to a **side**: every unit on a side obeys that side's input. That's exactly
  how the original's squadrons flew in formation.

## Steps

Do these in order, running `mix test` after each.

### 1. Rename `Tank` to `Unit` (mechanical)

- Rename the file and module, and update all references. `mix compile` lists every place you
  missed: let the compiler do the searching.
- Add `side` and change `id` to an integer. Add a `speed` field (current speed). Tanks won't use
  it, but planes will.
- `state.tanks` → `state.units`. Fix `Game.new`, `move_*`, `fire_*` and `resolve_shell_hits`.
- **Hits:** a shell hits any unit whose `side` differs from the shell's `side`.
- **One shell per unit:** a unit can fire only if no live shell has `shooter == unit.id`.
- **Snapshot:** `tanks` → `units`. Each entry is `%{id: 3, side: "p1", x:, y:, dir:, spinning:}`.
  Update the JS renderer at the same time: there's one integration point, so change both sides
  together.
- Update tests. Test helpers like `place_tank/4` become `place_unit/4`.

### 2. Define the behaviour (`lib/combat/game/mode.ex`)

| Callback | Purpose |
|---|---|
| `name() :: String.t()` | `"tank"`; also used in the snapshot and URL |
| `arena(opts :: map) :: Arena.t()` | Which arena to play in |
| `spawn_units(Arena.t(), opts :: map) :: [Unit.t()]` | Initial units for both sides |
| `move_unit(Unit.t(), Input.t(), dt :: float, ctx :: map) :: Unit.t()` | Per-unit movement. `ctx` has `obstacles` and `arena` |
| `weapon() :: %{speed: float, lifetime: float, reload: float}` | Shell tuning |
| `shells_hit_walls?() :: boolean` | Do walls stop shells? |
| `wrap?() :: boolean` | Do units and shells wrap around the screen edges? |
| `visible?(Unit.t(), State.t()) :: boolean` | Default `true`. Used for clouds in guide 11 |
| `round_seconds() :: number` | Default `136` |

Provide `__using__/1` with defaults for `visible?/2`, `round_seconds/0` and `wrap?/0` (`false`).

### 3. `Combat.Game.Modes.Tank`

Move the tank-specific code here:

- `arena/1` returns `Arenas.maze()` (or reads `opts[:arena]`).
- `spawn_units/2` creates one unit per side from the arena spawns.
- `move_unit/4` delegates to the code in `Combat.Game.Movement`. Either move that module's
  contents here, or keep `Movement` as a library of shared helpers (rotation, cooldowns and the
  slide algorithm are useful to every mode). **Shared helpers are the better choice:** biplanes
  reuse rotation and cooldowns.
- `weapon/0`, `shells_hit_walls?/0` and so on return the numbers from guide 04.

### 4. Make the core call the mode

- `State` gains `mode: module` and `opts: map`.
- `Game.new(mode, opts \\ %{})` asks the mode for the arena and units.
- Each tick step that had tank assumptions now asks the mode, e.g.
  `if state.mode.shells_hit_walls?(), do: resolve_shell_walls(state), else: state`.
- Add a generic `wrap_positions/1` step to the pipeline, which only runs when `mode.wrap?()`.
  Use `Vec`/`Integer.mod`-style wrapping that works for floats: `x - width * floor(x / width)`.
- `snapshot/1` adds `mode: state.mode.name()` and **filters** units through
  `state.mode.visible?/2`.

That last point is worth pausing on. Because the server decides what's visible, a hidden plane
**isn't in the snapshot at all.** A cheater reading WebSocket frames learns nothing. Client-side
hiding could never offer that.

### 5. A mode registry, and safety with user input

`Combat.Game.Modes` (`lib/combat/game/modes.ex`):

- `all() :: [module]`
- `fetch(name :: String.t()) :: {:ok, module} | :error`, built from a map of `name() => module`.
  The lobby form sends a string, and we **never** turn user strings into module atoms with
  `String.to_existing_atom` or `Module.concat`. A whitelist is the only safe approach.

### 6. Thread the mode through the shell

- `GameServer.start_link/1` and `Matches.create_match/1` take `mode: "tank"` (default) and
  resolve it with `Modes.fetch/1`. An unknown mode returns `{:error, :unknown_mode}`.
- The lobby form gets a `<.input type="select">` listing `Modes.all()`.
- `arena_info` includes the `mode`, and the JS renderer picks drawing functions by mode
  (`drawers[mode].unit(ctx, unit)`), so the guides 11/12 renderers slot in neatly.

## Tests

- Everything from before still passes. That's the point of a refactor.
- New: a **fake mode** in `test/support/` (`Combat.Game.Modes.Test`) with a tiny arena, a
  `move_unit` that moves straight right, and `wrap?` true. Assert that the core wraps a unit
  walking off the right edge back to the left. Testing the core against a fake proves the core
  really is mode-agnostic.
- `Modes.fetch("tank")` returns `{:ok, Modes.Tank}`, and `Modes.fetch("Elixir.File")` returns
  `:error`.

## Checkpoint

`mix test` is green, the game in the browser plays identically to guide 09, and the lobby shows a
mode dropdown with one entry. Commit before starting the planes.

## Stretch goals

- Move the guide 04 variants (ricochet, guided missiles) into **options** of the tank mode,
  selectable in the lobby: `opts: %{ricochet: true}`.
- Add a `@callback describe() :: String.t()` and show the rules on the waiting-room screen.

Next: [11 — Biplanes](11-biplanes.md)
