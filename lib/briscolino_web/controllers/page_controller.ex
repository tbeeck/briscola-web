defmodule BriscolinoWeb.PageController do
  alias BriscolinoWeb.UserSessions
  alias Briscolino.GameSupervisor
  alias Briscolino.GameServer
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

  def new_sp_game(conn, _params) do
    bot = %GameServer.PlayerInfo{
      ai_strategy: Briscola.Strategy.Random,
      name: UserSessions.random_username() <> " (AI)"
    }

    play_token = get_session(conn)["session_id"]

    players =
      [%GameServer.PlayerInfo{play_token: play_token, name: "You"}] ++
        List.duplicate(bot, 3)

    {:ok, pid} = GameSupervisor.new_game(players)
    {:ok, game} = GameServer.state(pid)

    conn
    |> redirect(to: "/game/#{game.id}")
  end
end
