defmodule Combat.GameTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Combat.Game
  alias Combat.Game.{State, Arenas, Tank, Input, Collision}
  doctest Combat.Game

  describe "new/1" do
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

  describe "set_input/3" do
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

  describe "start/1" do
    test "sets status to :playing" do
      state = Game.new(Arenas.open_field())

      assert %State{status: :playing} = Game.start(state)
    end
  end

  describe "tick/2" do
    setup do
      %{
        state: Game.new(Arenas.open_field())
      }
    end

    test "returns state unchanged if not playing", %{state: state} do
      assert ^state = Game.tick(state, 0.1)
    end

    test "moves both tanks after tick", %{state: state} do
      state = Game.start(state)
      state = %{state | inputs: %{p1: %Input{forward: true}, p2: %Input{forward: true}}}

      assert %State{
               tanks: %{
                 p1: %Tank{pos: {28.0, 45.0}, dir: 0},
                 p2: %Tank{pos: {132.0, 45.0}, dir: 8}
               }
             } =
               Game.tick(state, 0.1)
    end

    test "head on collision between tanks blocks each other", %{state: state} do
      state = Game.start(state)

      state = %{
        state
        | tanks: %{
            p1: %Tank{id: :p1, pos: {12.0, 50.0}, dir: 0},
            p2: %Tank{id: :p2, pos: {19.0, 50.0}, dir: 8}
          },
          inputs: %{p1: %Input{forward: true}, p2: %Input{forward: true}}
      }

      assert %State{tanks: %{p1: %Tank{pos: {12.0, 50.0}}, p2: %Tank{pos: {19.0, 50.0}}}} =
               Game.tick(state, 0.1)
    end

    test "overlapping moves are undone but rotation and cooldown are kept", %{state: state} do
      state = Game.start(state)

      state = %{
        state
        | tanks: %{
            # facing east
            p1: %Tank{id: :p1, pos: {74.25, 50.0}, dir: 0},
            # facing west
            p2: %Tank{id: :p2, pos: {81.75, 50.0}, dir: 8}
          },
          inputs: %{p1: %Input{forward: true, left: true}, p2: %Input{forward: true}}
      }

      # fire a single game tick
      state = Game.tick(state, 1 / 30)

      turn_interval = Tank.turn_interval()

      # assert tank's positions unchanged (due to overlap) but p1 still turning
      assert %State{
               tanks: %{
                 p1: %Tank{
                   id: :p1,
                   pos: {74.25, 50.0},
                   dir: 15,
                   turn_cooldown: ^turn_interval
                 },
                 p2: %Tank{id: :p2, pos: {81.75, 50.0}, dir: 8}
               }
             } = state
    end

    test "makes progress after tanks block", %{state: state} do
      state = Game.start(state)

      state = %{
        state
        | tanks: %{
            # facing east
            p1: %Tank{id: :p1, pos: {74.25, 50.0}, dir: 0},
            # facing west
            p2: %Tank{id: :p2, pos: {81.75, 50.0}, dir: 8}
          },
          inputs: %{p1: %Input{forward: true, left: true}, p2: %Input{forward: true}}
      }

      states = run_history(state, 30)

      # assert tanks never overlap
      assert Enum.all?(states, fn s ->
               not Collision.overlaps?(Tank.bounds(s.tanks.p1), Tank.bounds(s.tanks.p2))
             end)

      # assert tanks have made progress
      assert %State{
               tanks: %{p1: %Tank{pos: {x1, y1}, dir: 6}, p2: %Tank{pos: {x2, y2}, dir: 8}}
             } =
               List.last(states)

      assert_in_delta(60.70, x1, 1.0e-2)
      assert_in_delta(41.46, y1, 1.0e-2)

      assert x2 < 81.75
      assert 50.0 = y2
    end
  end

  describe "invariants" do
    property "tanks never overlap walls or each other whatever the inputs" do
      check all(script <- list_of({input_gen(), input_gen(), integer(1..20)}, max_length: 500)) do
        state =
          Arenas.maze()
          |> Game.new()
          |> Game.start()

        Enum.reduce(script, state, fn {p1_input, p2_input, steps}, game ->
          states =
            game
            |> Game.set_input(:p1, p1_input)
            |> Game.set_input(:p2, p2_input)
            |> run_history(steps)

          # assert p1 and p2 never overlap walls or each other
          Enum.each(states, fn s ->
            refute Collision.any_overlap?(Tank.bounds(s.tanks.p1), s.arena.walls)
            refute Collision.any_overlap?(Tank.bounds(s.tanks.p2), s.arena.walls)
            refute Collision.overlaps?(Tank.bounds(s.tanks.p1), Tank.bounds(s.tanks.p2))
          end)

          List.last(states)
        end)
      end
    end
  end

  defp run_history(state, ticks, dt \\ 1 / 30),
    do: Enum.scan(1..ticks, state, fn _, s -> Game.tick(s, dt) end)

  # defp run(state, ticks, dt \\ 1 / 30), do: run_history(state, ticks, dt) |> List.last()

  # input_gen() is a stream_data generator that returns a new value each time
  # StreamData asks for a value. Used to create the random movement for the
  # property test above. Note that the generators below are very naive, 25% of
  # the time it will return true for both forward and back or both left and
  # right which won't result in any change in state. StreamData does provide
  # tools for biasing the generated stream but adding this is a refinement.
  defp input_gen() do
    gen all(
          forward <- boolean(),
          back <- boolean(),
          left <- boolean(),
          right <- boolean()
        ) do
      %Input{forward: forward, back: back, left: left, right: right}
    end
  end
end
