defmodule BriscolinoWeb.PageController do
  alias Briscolino.LobbyServer
  alias Briscolino.LobbySupervisor
  use BriscolinoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def about(conn, _params) do
    render(conn, :about)
  end

  def new_lobby(conn, _parmas) do
    {:ok, pid} = LobbySupervisor.new_lobby()

    {:ok, lobby} =
      LobbyServer.state(pid)

    conn
    |> redirect(to: "/lobby/#{lobby.id}")
  end
end
