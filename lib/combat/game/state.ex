defmodule Combat.Game.State do
  @moduledoc """
  State is a module holding a data structure representing the current state of a
  single game.
  """

  alias Combat.Game.{Input, Arena, Tank, Shell}

  @enforce_keys [:arena]
  defstruct [
    :arena,
    # placeholder value - Game.new/1 always fills both slots
    tanks: %{},
    shells: [],
    inputs: %{p1: Input.new(), p2: Input.new()},
    scores: %{p1: 0, p2: 0},
    time_left: 136.0,
    status: :waiting,
    winner: nil,
    next_id: 1
  ]

  @typedoc """
  The two possible slots (representing the players) that a game may have.
  """
  @type slot() :: :p1 | :p2

  @typedoc """
  Represents the current game state.
  """
  @type t() :: %__MODULE__{
          arena: Arena.t(),
          tanks: %{p1: Tank.t(), p2: Tank.t()},
          shells: [Shell.t()],
          inputs: %{p1: Input.t(), p2: Input.t()},
          scores: %{p1: non_neg_integer(), p2: non_neg_integer()},
          time_left: float(),
          status: :waiting | :playing | :over,
          winner: slot() | :draw | nil,
          next_id: pos_integer()
        }
end
