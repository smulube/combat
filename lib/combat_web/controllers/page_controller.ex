defmodule CombatWeb.PageController do
  use CombatWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
