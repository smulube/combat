defmodule Combat.Game.Movement do
  @moduledoc """
  This module provides functions for calculating tank movement and collisions
  with obstacles within the arena.
  """
  alias Combat.Game.{Tank, Input, Arena, Vec, Collision}

  @spec move_tank(Tank.t(), Input.t(), float(), [Arena.rect()]) :: Tank.t()
  def move_tank(%Tank{} = tank, %Input{} = input, dt, obstacles) do
    tank
    |> tick_cooldowns(dt)
    |> rotate(input)
    |> translate(input, dt, obstacles)
  end

  # decrement the cooldown field by the dt tick interval
  defp tick_cooldowns(%Tank{} = tank, dt) do
    %{tank | turn_cooldown: max(tank.turn_cooldown - dt, 0.0)}
  end

  # the tank should only rotate when cooldown reaches 0
  defp rotate(%Tank{turn_cooldown: c} = tank, _input) when c > 0.0, do: tank

  defp rotate(%Tank{} = tank, %Input{} = input) do
    rotation =
      case {input.left, input.right} do
        {true, false} ->
          -1

        {false, true} ->
          1

        _ ->
          0
      end

    case rotation do
      0 ->
        tank

      _ ->
        %{tank | dir: Vec.rotate_dir(tank.dir, rotation), turn_cooldown: Tank.turn_interval()}
    end
  end

  defp translate(%Tank{} = tank, %Input{} = input, dt, obstacles) do
    speed_factor =
      case {input.forward, input.back} do
        {true, false} ->
          1.0

        {false, true} ->
          -0.5

        _ ->
          0.0
      end

    case speed_factor do
      +0.0 ->
        tank

      _ ->
        {dx, dy} =
          tank.dir
          |> Vec.from_dir()
          |> Vec.scale(Tank.speed() * speed_factor * dt)

        # find_value here returns the first truthy value from the enumeration
        # (i.e. anything but nil or false)
        Enum.find_value([{dx, dy}, {dx, 0.0}, {0.0, dy}], tank, fn displacement ->
          case try_move(tank, displacement, obstacles) do
            :blocked -> nil
            {:ok, displaced_tank} -> displaced_tank
          end
        end)
    end
  end

  @spec try_move(Tank.t(), Vec.t(), [Arena.rect()]) :: {:ok, Tank.t()} | :blocked
  defp try_move(tank, displacement, obstacles) do
    proposed_tank = %{tank | pos: Vec.add(tank.pos, displacement)}
    bounds = Tank.bounds(proposed_tank)

    if Collision.any_overlap?(bounds, obstacles) do
      :blocked
    else
      {:ok, proposed_tank}
    end
  end
end
