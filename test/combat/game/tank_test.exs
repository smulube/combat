defmodule Combat.Game.TankTest do
  use ExUnit.Case, async: true
  alias Combat.Game.Tank

  doctest Combat.Game.Tank

  test "bounds returns size x size rectangle centred on pos" do
    tank = %Tank{id: :p1, pos: {10.0, 20.0}}
    assert Tank.bounds(tank) == %{x: 7.0, y: 17.0, w: 6.0, h: 6.0}
  end
end
