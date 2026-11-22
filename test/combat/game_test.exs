defmodule Combat.GameTest do
  use ExUnit.Case, async: true
  alias Combat.Game
  alias Combat.Game.{State, Arenas, Tank, Input}
  doctest Combat.Game

  describe "new" do
    test "initialises tanks at the spawn positions" do
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

  describe "set_input" do
    test "sets a p1 input to the state" do
      state = Game.new(Arenas.open_field())

      assert %State{inputs: %{p1: %Input{fire: true}}} =
               Game.set_input(state, :p1, %Input{fire: true})
    end

    test "raises if given an unknown slot" do
      state = Game.new(Arenas.open_field())

      # building atom at runtime means we don't see the noisy type warning
      slot = String.to_atom("p3")

      assert_raise FunctionClauseError, fn ->
        Game.set_input(state, slot, %Input{forward: true})
      end
    end
  end

  describe "start" do
    test "sets status to :playing" do
      state = Game.new(Arenas.open_field())

      assert %State{status: :playing} = Game.start(state)
    end
  end
end
