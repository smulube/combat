defmodule Combat.Game.CollisionTest do
  use ExUnit.Case, async: true
  alias Combat.Game.Collision
  doctest Combat.Game.Collision

  describe "overlaps?" do
    test "when one rectangle fully inside another" do
      large_rect = %{x: 1, y: 1, w: 10, h: 10}
      small_rect = %{x: 5, y: 5, w: 1, h: 1}
      assert Collision.overlaps?(large_rect, small_rect)
      assert Collision.overlaps?(small_rect, large_rect)
    end

    test "when two rectangles side by side" do
      rect_1 = %{x: 1, y: 1, w: 1, h: 1}
      rect_2 = %{x: 2, y: 1, w: 1, h: 1}
      refute Collision.overlaps?(rect_1, rect_2)
    end
  end
end
