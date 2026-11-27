defmodule Combat.Game do
  @moduledoc """
  Game exposes functions which are the public API of the core game engine.
  """

  alias Combat.Game.Collision
  alias Combat.Game.{Arena, State, Tank, Input, Movement}

  @doc """
  Initialises a new game.
  """
  @spec new(Arena.t()) :: State.t()
  def new(%Arena{spawns: %{p1: p1_spawn, p2: p2_spawn}} = arena) do
    %State{
      arena: arena,
      tanks: %{
        p1: build_tank(:p1, p1_spawn),
        p2: build_tank(:p2, p2_spawn)
      }
    }
  end

  @doc """
  Sets an input into the state and returns the new state struct.
  """
  @spec set_input(State.t(), State.slot(), Input.t()) :: State.t()
  def set_input(%State{} = state, slot, %Input{} = input) when slot in [:p1, :p2] do
    put_in(state.inputs[slot], input)
  end

  @doc """
  Starts the game (sets status to :playing).
  """
  @spec start(State.t()) :: State.t()
  def start(%State{} = state) do
    %{state | status: :playing}
  end

  @doc """
  This function processes a single game tick, updating the state of a single
  game as a result of user inputs.
  """
  @spec tick(State.t(), float()) :: State.t()
  def tick(%State{status: :playing} = state, dt) do
    state
    |> move_tanks(dt)
  end

  def tick(%State{} = state, _dt), do: state

  @spec build_tank(State.slot(), Arena.spawn()) :: Tank.t()
  defp build_tank(id, {x, y, dir}) do
    %Tank{
      id: id,
      pos: {x, y},
      dir: dir
    }
  end

  # move_tanks/2 attempts to update both tanks position given the current inputs
  # by calling Movement.move_tank/4 for each tank. This check also checks for
  # collisions with the other tank, and for fairness this check happens with the
  # previous location of each tank.
  defp move_tanks(
         %State{
           arena: arena,
           tanks: %{p1: p1_tank, p2: p2_tank},
           inputs: %{p1: p1_input, p2: p2_input}
         } = state,
         dt
       ) do
    new_p1 = Movement.move_tank(p1_tank, p1_input, dt, [Tank.bounds(p2_tank) | arena.walls])
    new_p2 = Movement.move_tank(p2_tank, p2_input, dt, [Tank.bounds(p1_tank) | arena.walls])

    {new_p1, new_p2} =
      if Collision.overlaps?(Tank.bounds(new_p1), Tank.bounds(new_p2)) do
        # if the tanks overlap we want to restore the original position of the
        # tank, but keep all other changes that move_tank applied
        {%{new_p1 | pos: p1_tank.pos}, %{new_p2 | pos: p2_tank.pos}}
      else
        {new_p1, new_p2}
      end

    %{state | tanks: %{p1: new_p1, p2: new_p2}}
  end
end
