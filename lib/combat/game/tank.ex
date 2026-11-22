defmodule Combat.Game.Tank do
  @moduledoc """
  This module contains a struct modeling the Tank type that is the vehicle
  controlled by the player when playing the game.
  """

  alias Combat.Game.{Tank, Vec, Arena, State}

  @enforce_keys [:id, :pos]
  defstruct [:id, :pos, dir: 0, turn_cooldown: 0.0, reload: 0.0, spin: 0.0]

  # the hitbox for the tank (this value is the side length of a square centered
  # on pos).
  @size 6.0
  # units/second
  @speed 30.0
  # seconds per rotation step
  @turn_interval 0.08

  @typedoc """
  Defines the data structure for the tank (which is the player controlled
  vehicle).
  """
  @type t() :: %__MODULE__{
          id: State.slot(),
          pos: Vec.t(),
          dir: Vec.dir(),
          turn_cooldown: float(),
          reload: float(),
          spin: float()
        }

  @doc """
  Returns the size attribute.
  """
  @spec size() :: float()
  def size(), do: @size

  @doc """
  Returns the speed attribute.
  """
  @spec speed() :: float()
  def speed(), do: @speed

  @doc """
  Returns the turn interval attribute.
  """
  @spec turn_interval() :: float()
  def turn_interval(), do: @turn_interval

  @doc """
  Returns the bounds of the tank in the same shape as arena walls meaning a
  single collision function will be able to handle everything.
  """
  @spec bounds(t()) :: Arena.rect()
  def bounds(%Tank{pos: {x, y}}) do
    %{x: x - @size / 2, y: y - @size / 2, w: @size, h: @size}
  end
end
