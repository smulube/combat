defmodule Combat.Game do
  @moduledoc """
  Game exposes functions which are the public API of the core game engine.
  """

  alias Combat.Game.{Arena, State, Tank, Input}

  @doc """
  Initialises a new game.
  """
  @spec new(Arena.t()) :: State.t()
  def new(%Arena{spawns: %{p1: p1_spawn, p2: p2_spawn}} = arena) do
    %State{
      arena: arena,
      tanks: %{
        p1: build_tank(:p1, p1_spawn),
        p2: build_tank(:p2, p2_spawn)
      }
    }
  end

  @doc """
  Sets an input into the state and returns the new state struct.
  """
  @spec set_input(State.t(), State.slot(), Input.t()) :: State.t()
  def set_input(%State{} = state, slot, %Input{} = input) when slot in [:p1, :p2] do
    put_in(state.inputs[slot], input)
  end

  @doc """
  Starts the game (sets status to :playing).
  """
  @spec start(State.t()) :: State.t()
  def start(%State{} = state) do
    %{state | status: :playing}
  end

  @spec build_tank(State.slot(), Arena.spawn()) :: Tank.t()
  defp build_tank(id, {x, y, dir}) do
    %Tank{
      id: id,
      pos: {x, y},
      dir: dir
    }
  end
end
