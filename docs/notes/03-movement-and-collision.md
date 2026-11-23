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
