# Goals

The aim of this section is to extend the current pure functions comprising the
game core with functions for modelling how we handle the core game tick
(function that receives the current state, inputs, and a time tick difference -
it applies the inputs and the time tick difference and returns a new State).

This type of data model maps really nicely to piped functions in Elixir (pattern
I know and have used both in Elixir and Clojure)
