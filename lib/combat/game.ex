defmodule Combat.Game do
  @moduledoc """
  Game exposes functions which are the public API of the core game engine.
  """

  alias Combat.Game.{Arena, State, Tank}

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

  @spec build_tank(State.slot(), Arena.spawn()) :: Tank.t()
  defp build_tank(id, {x, y, dir}) do
    %Tank{
      id: id,
      pos: {x, y},
      dir: dir
    }
  end
end
