# Goals

The aim of this section is to extend the current pure functions comprising the
game core with functions for modelling how we handle the core game tick
(function that receives the current state, inputs, and a time tick difference -
it applies the inputs and the time tick difference and returns a new State).

This type of data model maps really nicely to piped functions in Elixir (pattern
I know and have used both in Elixir and Clojure)

## Notes

- Use `put_in` for updating nested fields inside a struct, but for simple cases we can use the "quick" syntax: `%{state | status: :playing}`

### Movement

- A tank has an id, position (x,y), direction (0..15)), cooldown time, reload time and spin time
- when calculating movement if turn_cooldown is > 0 then we don't change anything about movement (I think)
- a change in direction should do some math modulo

## Property Testing

- property test describes a rule that must hold for every input
- StreamData then generates hundreds of random inputs and checks the rule
  against each one. If any input breaks the rule it shrinks that input down to
  the smallest version that still fails and reports that

Rule here is: whatever buttons the players press, in whatever order, for however
long, a tank never ends up overlappingi a wall

The shape of the test will look something like:

```elixir
defmodule Combat.GamePRopertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties # from stream_data

  property "tanks never overlap a wall, whatever the inputs" do
    check all script <- list_of({input_gen(), integer(1..20)}, max_length: 30) do
      # start from Arenas.max() |> Game.new() |> Game.start()
      # for each {input, ticks} in script:
      #   set the input (one tank, or both)
      #   tick that many times with dt = 1/30
      #   after EVERY tick, assert neither tank's bounds overlap any wall
    end
  end
end
```
