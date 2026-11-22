defmodule Combat.GameTest do
  use ExUnit.Case, async: true
  alias Combat.Game
  alias Combat.Game.{State, Arenas, Tank}
  doctest Combat.Game

  test "new game initialises tanks at the spawn positions" do
    arena = Arenas.open_field()
    state = Game.new(arena)
    %{p1: {x1, y1, dir1}, p2: {x2, y2, dir2}} = arena.spawns

    assert %State{
             tanks: %{
               p1: %Tank{pos: {^x1, ^y1}, dir: ^dir1},
               p2: %Tank{pos: {^x2, ^y2}, dir: ^dir2}
             }
           } = state
  end

  test "starts in the waiting state with zero scores" do
    state = Game.new(Arenas.open_field())

    assert %State{
             status: :waiting,
             scores: %{p1: 0, p2: 0}
           } = state
  end
end
