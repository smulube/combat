defmodule Combat.Game.Input do
  @moduledoc """
  Input defines a struct representing an input sent by the player for what
  control keys they are currently holding down.
  """

  defstruct left: false, right: false, forward: false, back: false, fire: false

  @typedoc """
  An input control message.
  """
  @type t() :: %__MODULE__{
          left: boolean(),
          right: boolean(),
          forward: boolean(),
          back: boolean(),
          fire: boolean()
        }

  @doc """
  Returns a new Combat.Game.Input instance with all false fields.

  ## Examples

      iex> Combat.Game.Input.new()
      %Combat.Game.Input{left: false, right: false, forward: false, back: false, fire: false}
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Returns a new Combat.Game.Input instance built from a passed in map where
  string keys must match expected values exactly meaning unknown keys are
  ignored. Any value other than a boolean true counts as false.

  ## Examples

      iex> Combat.Game.Input.from_params(%{"right" => true})
      %Combat.Game.Input{left: false, right: true, forward: false, back: false, fire: false}
  """
  @spec from_params(term()) :: t()
  def from_params(params) when is_map(params) do
    %__MODULE__{
      left: Map.get(params, "left") == true,
      right: Map.get(params, "right") == true,
      forward: Map.get(params, "forward") == true,
      back: Map.get(params, "back") == true,
      fire: Map.get(params, "fire") == true
    }
  end

  def from_params(_), do: %__MODULE__{}
end
