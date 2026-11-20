defmodule Combat.Game.Arena do
  @moduledoc """
  Arena defines a struct that models the game arena within which the combat
  takes place. The arena width and height values are sizes in logical units
  (typically 160 * 100), and walls are given as top-left corner plus size.
  """
  alias Combat.Game.Vec

  @enforce_keys [:width, :height, :walls, :spawns]
  defstruct [:width, :height, :walls, :spawns]

  @typedoc """
  Defines a rect type that is a solid rectangle defined as the top left corner,
  width and height.
  """
  @type rect() :: %{x: number(), y: number(), w: number(), h: number()}

  @typedoc """
  Defines the spawn point for one of the players defined as the vehicle's
  starting centre point and direction, {x, y, dir}.
  """
  @type spawn() :: {number(), number(), Vec.dir()}

  @typedoc """
  Defines the arena within which a game takes place.
  """
  @type t() :: %__MODULE__{
          width: number(),
          height: number(),
          walls: [rect()],
          spawns: %{p1: spawn(), p2: spawn()}
        }
end
