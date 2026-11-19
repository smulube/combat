defmodule CombatWeb.GameHTML do
  @moduledoc """
  This module contains pages rendered by GameController.
  """

  use CombatWeb, :html

  embed_templates "game_html/*"
end
