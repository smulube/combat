defmodule Combat.Game.Shell do
  @moduledoc """
  Defines the data structure for the shells fired by vehicles when playing the
  game.
  """

  alias Combat.Game.{Vec, State}

  @enforce_keys [:id, :owner, :pos, :vel, :ttl]
  defstruct [:id, :owner, :pos, :vel, :ttl]

  @typedoc """
  A shell fired by a player. The vel field in the struct reuses the base Vec.t()
  type, however the values it holds will be in units/second not a simple `x, y`
  position.
  """
  @type t() :: %__MODULE__{
          id: pos_integer(),
          owner: State.slot(),
          pos: Vec.t(),
          vel: Vec.t(),
          ttl: float()
        }
end
