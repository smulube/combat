defmodule Combat.Game.VecTest do
  use ExUnit.Case, async: true
  alias Combat.Game.Vec
  doctest Combat.Game.Vec

  test "direction 4 points straight down (y grows downwards)" do
    {x, y} = Vec.from_dir(4)
    assert_in_delta x, 0.0, 1.0e-9
    assert_in_delta y, 1.0, 1.0e-9
  end

  test "direction 8 points straight left" do
    {x, y} = Vec.from_dir(8)
    assert_in_delta x, -1.0, 1.0e-9
    assert_in_delta y, 0.0, 1.0e-9
  end

  test "direction 12 points straight up" do
    {x, y} = Vec.from_dir(12)
    assert_in_delta x, 0.0, 1.0e-9
    assert_in_delta y, -1.0, 1.0e-9
  end

  test "direction 2 points diagonally down and right verifying clockwise rotation" do
    {x, y} = Vec.from_dir(2)
    assert x > 0
    assert y > 0
  end

  test "all directions have approximate length of 1.0" do
    for n <- 0..15 do
      assert_in_delta Vec.length(Vec.from_dir(n)),
                      1.0,
                      1.0e-9,
                      "unexpected value for direction #{n}"
    end
  end
end
