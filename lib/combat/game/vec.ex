defmodule Combat.Game.Vec do
  @moduledoc """
  This module contains helper functions for working with 2d vectors which will
  be used everywhere in the core game logic. The vectors are represented as an
  `{x, y}` tuple of floats, where positive x points right, and positive y values
  point down.
  """

  @typedoc """
  A 2d vector.
  """
  @type t() :: {float(), float()}

  @typedoc """
  One of 16 compass directions (0..15), in steps of 22.5°, where 0 is due east
  (right), proceeding clockwise (so 4 is due south, 8 is due west, etc.)
  """
  @type dir() :: 0..15

  @directions 16

  @unit_vectors (for n <- 0..15 do
                   angle = n * 2 * :math.pi() / @directions
                   {:math.cos(angle), :math.sin(angle)}
                 end)
                |> List.to_tuple()

  @doc """
  Adds two 2d vectors together.

  ## Examples

      iex> Combat.Game.Vec.add({0.0, 0.0}, {1.0, 2.0})
      {1.0, 2.0}

      iex> Combat.Game.Vec.add({1.0, 0.5}, {0.0, -2.0})
      {1.0, -1.5}
  """
  @spec add(t(), t()) :: t()
  def add({x1, y1}, {x2, y2}), do: {x1 + x2, y1 + y2}

  @doc """
  Subtracts one 2d vector from another.

  ## Examples

      iex> Combat.Game.Vec.sub({1.0, 0.0}, {2.5, 1.0})
      {-1.5, -1.0}
  """
  @spec sub(t(), t()) :: t()
  def sub({x1, y1}, {x2, y2}), do: {x1 - x2, y1 - y2}

  @doc """
  Scale a 2d vector by multiplying each element by a scale factor.

  ## Examples

      iex> Combat.Game.Vec.scale({1.0, 2.0}, 3)
      {3.0, 6.0}

      iex> Combat.Game.Vec.scale({1.0, 2.0}, -1)
      {-1.0, -2.0}
  """
  @spec scale(t(), number()) :: t()
  def scale({x, y}, factor), do: {x * factor, y * factor}

  @doc """
  Calculate the Euclidean length of a 2d vector using the Pythagorean theorem.

  ## Examples

      iex> Combat.Game.Vec.length({3.0, 4.0})
      5.0
  """
  @spec length(t()) :: float()
  def length({x, y}), do: :math.sqrt(x * x + y * y)

  @doc """
  Returns the unit vector for a direction index. Note this uses a static lookup
  table rather than dynamically calculating cos/sin pairs for a given direction.
  The convention we follow here is that a direction index of 0 points right (the
  `{1.0, 0.0}` case below), increasing the index rotates clockwise meaning that
  for example an index of 4 points down.

  ## Examples

      iex> Combat.Game.Vec.from_dir(0)
      {1.0, 0.0}
  """
  @spec from_dir(dir()) :: t()
  def from_dir(dir), do: elem(@unit_vectors, dir)

  @doc """
  Given the current direction and a delta change to the direction this function
  returns the resulting direction ensuring the result maps round to our fixed
  range of 0..15. Positive delta values rotate clockwise meaning that negative
  delta represents an anticlockwise rotation.

  ## Examples

      iex> Combat.Game.Vec.rotate_dir(0, -1)
      15

      iex> Combat.Game.Vec.rotate_dir(3, 15)
      2

      iex> Combat.Game.Vec.rotate_dir(7, -2)
      5

      iex> Combat.Game.Vec.rotate_dir(15, 1)
      0

      iex> Combat.Game.Vec.rotate_dir(4, 18)
      6
  """
  @spec rotate_dir(dir(), integer()) :: dir()
  def rotate_dir(dir, delta), do: Integer.mod(dir + delta, @directions)
end
