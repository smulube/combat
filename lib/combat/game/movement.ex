defmodule Combat.Game.Movement do
  alias Combat.Game.{Tank, Input, Arena, Vec}
  @spec move_tank(Tank.t(), Input.t(), float(), [Arena.rect()]) :: Tank.t()
  def move_tank(%Tank{} = tank, %Input{} = input, dt, _obstacles) do
    tank
    |> tick_cooldowns(dt)
    |> rotate(input)
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
end
