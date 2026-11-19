defmodule CombatWeb.GameController do
  use CombatWeb, :controller

  def show(conn, %{"match_id" => match_id}) do
    render(conn, :show, match_id: match_id)
  end
end
