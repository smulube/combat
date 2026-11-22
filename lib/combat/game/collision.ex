defmodule Combat.Game.Collision do
  @moduledoc """
  This module provides functions for determining collisions (or overlaps)
  between rectangles and points.
  """
  alias Combat.Game.{Arena, Vec}

  @doc """
  Calculates whether two rectangles overlap.

  ## Examples

      iex> Combat.Game.Collision.overlaps?(%{x: 1, y: 1, w: 2, h: 3}, %{x: 2, y: 4, w: 3, h: 3})
      false

      iex> Combat.Game.Collision.overlaps?(%{x: 4, y: 5, w: 2, h: 2}, %{x: 2, y: 4, w: 3, h: 3})
      true

      iex> Combat.Game.Collision.overlaps?(%{x: 2, y: 10, w: 1, h: 1}, %{x: 10, y: 10, w: 1, h: 1})
      false
  """
  @spec overlaps?(Arena.rect(), Arena.rect()) :: boolean
  def overlaps?(a, b) do
    a.x < b.x + b.w and
      a.x + a.w > b.x and
      a.y < b.y + b.h and
      a.y + a.h > b.y
  end

  @doc """
  Returns true if the passed in rect overlaps with any of the rects passed in
  the second parameter list.

  ## Examples

      iex> Combat.Game.Collision.any_overlap?(%{x: 2, y: 4, w: 3, h: 2}, [%{x: 12, y: 12, w: 1, h: 1}, %{x: 4, y: 2, w: 3, h: 5}])
      true

      iex> Combat.Game.Collision.any_overlap?(%{x: 2, y: 4, w: 1, h: 1}, [])
      false
  """
  @spec any_overlap?(Arena.rect(), [Arena.rect()]) :: boolean
  def any_overlap?(rect, rects) do
    Enum.any?(rects, &overlaps?(rect, &1))
  end

  @doc """
  Returns true if the rectangle contains the point, false otherwise.

  ## Examples

      iex> Combat.Game.Collision.contains_point?(%{x: 1, y: 1, w: 5, h: 5}, {2, 2})
      true

      iex> Combat.Game.Collision.contains_point?(%{x: 1, y: 1, w: 5, h: 5}, {6, 2})
      false

      iex> Combat.Game.Collision.contains_point?(%{x: 1, y: 1, w: 5, h: 5}, {1, 2})
      true

      iex> Combat.Game.Collision.contains_point?(%{x: 1, y: 1, w: 5, h: 5}, {2, 1})
      true

      iex> Combat.Game.Collision.contains_point?(%{x: 1, y: 1, w: 5, h: 5}, {2, 6})
      false
  """
  @spec contains_point?(Arena.rect(), Vec.t()) :: boolean
  def contains_point?(rect, {x, y}) do
    x >= rect.x and
      x < rect.x + rect.w and
      y >= rect.y and
      y < rect.y + rect.h
  end
end
