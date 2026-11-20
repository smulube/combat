defmodule Combat.Game.Arenas do
  @moduledoc """
  Arenas exposes functions for building playable maps (arenas).
  """
  alias Combat.Game.Arena

  @width 160.0
  @height 100.0
  @wall 2.0
  @inset 10.0

  @doc """
  Returns the simplest starting map (an open area with border walls only, player
  1 spawns in the middle left facing east and player 2 spawns on middle right
  facing west).
  """
  @spec open_field() :: Arena.t()
  def open_field do
    %Arena{
      width: @width,
      height: @height,
      walls: [
        %{x: 0.0, y: 0.0, w: @width, h: @wall},
        %{x: @width - @wall, y: 0.0, w: @wall, h: @height},
        %{x: 0.0, y: @height - @wall, w: @width, h: @wall},
        %{x: 0.0, y: 0.0, w: @wall, h: @height}
      ],
      spawns: %{
        p1: {@wall + @inset, @height / 2, 0},
        p2: {@width - @wall - @inset, @height / 2, 8}
      }
    }
  end
end
