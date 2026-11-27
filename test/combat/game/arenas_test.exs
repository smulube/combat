defmodule Combat.Game.ArenasTest do
  use ExUnit.Case, async: true

  alias Combat.Game.{Arenas, Arena}

  @simple_grid """
  1#2
  ...
  .#.
  """

  describe "from_ascii/1" do
    test "calculates size from grid" do
      assert %Arena{width: 30.0, height: 30.0} = Arenas.from_ascii(@simple_grid)
    end

    test "builds walls correctly" do
      assert %Arena{
               walls: [
                 %{x: 10.0, y: +0.0, w: 10.0, h: 10.0},
                 %{x: 10.0, y: 20.0, w: 10.0, h: 10.0}
               ]
             } = Arenas.from_ascii(@simple_grid)
    end

    test "sets spawns correctly" do
      assert %Arena{
               spawns: %{p1: {5.0, 5.0, 0}, p2: {25.0, 5.0, 8}}
             } = Arenas.from_ascii(@simple_grid)
    end

    test "fails if grid missing spawn 1" do
      assert_raise FunctionClauseError, fn -> Arenas.from_ascii("###\n#.#\n#2#\n###") end
    end

    test "fails if grid missing spawn 2" do
      assert_raise FunctionClauseError, fn -> Arenas.from_ascii("###\n#.#\n#1#\n###") end
    end

    test "fails if grid has duplicate spawns" do
      assert_raise FunctionClauseError, fn -> Arenas.from_ascii("###\n#1#\n#1#\n###") end
    end

    test "trailing new line doesn't affect grid build" do
      arena_1 = Arenas.from_ascii("1#2\n...\n.#.")
      arena_2 = Arenas.from_ascii("1#2\n...\n.#.\n")
      assert arena_1 == arena_2
    end
  end

  describe "open_field/0" do
    test "builds the open field arena" do
      arena = Arenas.open_field()
      assert %Arena{} = arena
      assert length(arena.walls) == 18
      assert {_, _, _} = arena.spawns.p1
      assert {_, _, _} = arena.spawns.p2
    end
  end

  describe "maze" do
    test "builds the maze arena" do
      arena = Arenas.maze()
      assert 30 = length(arena.walls)
    end
  end
end
