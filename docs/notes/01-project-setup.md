# Setup

- pretty much followed the LLM notes here, initialised the project using
  standard Elixir commands
- Phoenix app rather than vanilla Elixir to make use of the robust channel
  implementation which is probably ideal for this sort of real time game
- Elixir will give us the nice OTP primitives of GenServers which will map to
  individual games between pairs of players.
- Elixir a good choice for this type of application, not at all the most
  performant but is designed for soft realtime, highly concurrent applications,
  blah...
