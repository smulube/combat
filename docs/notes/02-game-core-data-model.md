# Context

- The core idea for this section seems to be to create a set of modules
  containing data (structs) and functions that will provide the core
  functionality of the game.
- These functions and structs will not use any Elixir concurrency features - we
  want to be able to model all this logic using plain functions as much easier
  to test and develop without taking on concurrency and networking functionality
  as well
- Main public API will be a Game module (Combat.Game), but this will reference a
  bunch of data types (Vec, Tank, Arena, Shell, State) of which State is maybe
  most important representing the complete state of a game at some instant of
  time.

## Learnings

- `=` is a pattern matching operation (not an assignation), so remember we can
  use this to pattern match in tests to extract fields from a data structure and
  assert their value in a single line.
- Always define `@type` typespecs for our structs and functions that operate on
  them, greatly helps the compiler and the editor to keep you right
- remember functions not methods - think functions and data at all times.
- Good practice to provide moduledocs and docs for functions
- Testing - doctests are good for simple inline test cases, but remember to add
  the corresponding test file to enable them.
- Test files are macros so needs care for things like table tests that are
  trivial in Go as we have to unquote to break out of compile time context
