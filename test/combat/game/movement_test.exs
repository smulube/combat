defmodule Combat.Game.MovementTest do
  use ExUnit.Case, async: true

  alias Combat.Game.{Movement, Tank, Input, Vec}

  describe "move_tank/4" do
    setup do
      %{
        tank: %Tank{
          id: :p1,
          pos: {50.0, 50.0},
          dir: 4,
          turn_cooldown: 0.0
        }
      }
    end

    test "a basic turn left", %{tank: tank} do
      turn_interval = Tank.turn_interval()

      assert %Tank{
               dir: 3,
               turn_cooldown: ^turn_interval
             } =
               Movement.move_tank(
                 tank,
                 %Input{left: true},
                 0.033,
                 []
               )
    end

    test "a basic turn right", %{tank: tank} do
      turn_interval = Tank.turn_interval()

      assert %Tank{
               dir: 5,
               turn_cooldown: ^turn_interval
             } =
               Movement.move_tank(
                 tank,
                 %Input{right: true},
                 0.033,
                 []
               )
    end

    test "holding left for two ticks", %{tank: tank} do
      input = %Input{left: true}

      assert %Tank{
               dir: 3,
               turn_cooldown: cooldown
             } =
               tank
               |> Movement.move_tank(input, 0.033, [])
               |> Movement.move_tank(input, 0.033, [])

      assert_in_delta(Tank.turn_interval() - 0.033, cooldown, 1.0e-9)
    end

    test "no input does not reset cooldown", %{tank: tank} do
      assert %Tank{
               dir: 4,
               turn_cooldown: +0.0
             } = Movement.move_tank(tank, %Input{}, 0.033, [])
    end

    test "holding both rotation directions results in no change", %{tank: tank} do
      assert %Tank{
               dir: 4,
               turn_cooldown: +0.0
             } = Movement.move_tank(tank, %Input{left: true, right: true}, 0.033, [])
    end

    test "turning left at direction 0 wraps around correctly", %{tank: tank} do
      tank = %{tank | dir: 0}

      assert %Tank{
               dir: 15
             } = Movement.move_tank(tank, %Input{left: true}, 0.033, [])
    end

    test "turning right at direction 15 wraps around correctly", %{tank: tank} do
      tank = %{tank | dir: 15}

      assert %Tank{
               dir: 0
             } = Movement.move_tank(tank, %Input{right: true}, 0.033, [])
    end

    test "does not turn when mid cooldown", %{tank: tank} do
      tank = %{tank | turn_cooldown: 0.05}

      assert %Tank{
               dir: 4,
               turn_cooldown: cooldown
             } = Movement.move_tank(tank, %Input{right: true}, 0.033, [])

      assert_in_delta(0.05 - 0.033, cooldown, 1.0e-9)
    end

    test "turns when mid cooldown but dt is larger than cooldown", %{
      tank: tank
    } do
      tank = %{tank | turn_cooldown: 0.05}

      turn_interval = Tank.turn_interval()

      assert %Tank{
               dir: 5,
               turn_cooldown: ^turn_interval
             } = Movement.move_tank(tank, %Input{right: true}, 0.066, [])
    end

    test "turns when starting cooldown is exactly dt meaning it reaches zero", %{tank: tank} do
      tank = %{tank | turn_cooldown: 0.033}

      turn_interval = Tank.turn_interval()

      assert %Tank{
               dir: 3,
               turn_cooldown: ^turn_interval
             } = Movement.move_tank(tank, %Input{left: true}, 0.033, [])
    end

    test "forward movement east", %{tank: tank} do
      tank = %{tank | dir: 0}

      assert %Tank{
               pos: {53.0, 50.0}
             } = Movement.move_tank(tank, %Input{forward: true}, 0.1, [])
    end

    test "backward movement west", %{tank: tank} do
      tank = %{tank | dir: 0}

      assert %Tank{
               pos: {48.5, 50.0}
             } = Movement.move_tank(tank, %Input{back: true}, 0.1, [])
    end

    test "forward movement south", %{tank: tank} do
      assert %Tank{
               pos: {x, y}
             } = Movement.move_tank(tank, %Input{forward: true}, 0.1, [])

      assert_in_delta(x, 50.0, 1.0e-9)
      assert_in_delta(y, 53.0, 1.0e-9)
    end

    test "holding both forward and backward results in no displacement", %{tank: tank} do
      assert %Tank{
               pos: {50.0, 50.0}
             } = Movement.move_tank(tank, %Input{forward: true, back: true}, 0.1, [])
    end

    test "move and turn on the same tick", %{tank: tank} do
      assert %Tank{
               dir: 3,
               pos: {x, y}
             } = Movement.move_tank(tank, %Input{forward: true, left: true}, 0.1, [])

      {expected_x, expected_y} =
        3 |> Vec.from_dir() |> Vec.scale(Tank.speed() * 1.0 * 0.1) |> Vec.add(tank.pos)

      assert_in_delta(x, expected_x, 1.0e-9)
      assert_in_delta(y, expected_y, 1.0e-9)
    end

    test "moving east but with a perpendicular obstructing wall is blocked", %{tank: tank} do
      tank = %{tank | dir: 0}

      assert %Tank{
               pos: {50.0, 50.0}
             } =
               Movement.move_tank(tank, %Input{forward: true}, 0.1, [
                 %{x: 55.0, y: 10.0, w: 5.0, h: 80.0}
               ])
    end

    test "moving backward away from the perpendicular obstructing wall is possible", %{
      tank: tank
    } do
      tank = %{tank | dir: 0}

      assert %Tank{
               pos: {48.5, 50.0}
             } =
               Movement.move_tank(tank, %Input{back: true}, 0.1, [
                 %{x: 55.0, y: 10.0, w: 5.0, h: 80.0}
               ])
    end

    test "moving diagonally south-east when a north-south obstructing wall", %{tank: tank} do
      tank = %{tank | dir: 2}

      assert %Tank{
               pos: {x, y},
               dir: 2
             } =
               Movement.move_tank(tank, %Input{forward: true}, 0.1, [
                 %{x: 55.0, y: 10.0, w: 5.0, h: 80.0}
               ])

      assert_in_delta(x, 50.0, 1.0e-9)
      assert_in_delta(y, 52.12132034, 1.0e-6)
    end
  end
end
