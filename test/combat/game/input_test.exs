defmodule Combat.Game.InputTest do
  use ExUnit.Case, async: true
  alias Combat.Game.Input
  doctest Combat.Game.Input

  for {label, input, expected} <- [
        {"empty map", %{}, %Input{}},
        {"single correct value", %{"left" => true}, %Input{left: true}},
        {"non-boolean value treated as false", %{"left" => "yes"}, %Input{left: false}},
        {"nil value treated as false", %{"left" => nil}, %Input{left: false}},
        {"one valid, one invalid value", %{"hack" => true, "back" => true}, %Input{back: true}},
        {"string true value treated as false", %{"fire" => "true"}, %Input{}},
        {"invalid key and value on separate fields both treated as false",
         %{"fire" => "yes", "hack" => true}, %Input{}},
        {"non-map params", [], %Input{}}
      ] do
    test "from_params: #{label}" do
      assert Input.from_params(unquote(Macro.escape(input))) == unquote(Macro.escape(expected))
    end
  end
end
