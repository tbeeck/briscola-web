defmodule BriscolinoWeb.DebugController do
  use BriscolinoWeb, :controller

  alias Briscolino.GameServer.PlayerInfo
  alias Briscolino.GameSupervisor
  alias Briscolino.GameServer

  def devgame(conn, _params) do
    games =
      Briscolino.GameSupervisor.active_games()
      |> Enum.map(fn {id, pid} ->
        {:ok, state} = GameServer.state(pid)
        {id, pid, state}
      end)

    render(conn, :devgame, new_game: %{"players" => 2}, games: games)
  end

  def create_game(conn, params) do
    # Create a new game using the parameters from the form.
    players = Map.get(params, "players", "2") |> String.to_integer()
    {:ok, _pid} = Briscolino.GameSupervisor.new_ai_game()

    conn
    |> put_flash(:info, "Game created successfully")
    |> redirect(to: "/debug")
  end

  def create_game_sp(conn, _params) do
    player_key = Plug.Conn.get_session(conn, :session_id)
    bot = %PlayerInfo{ai_strategy: Briscola.Strategy.Random, name: "AI Player"}
    players = [%PlayerInfo{play_token: player_key, name: "You"}] ++ List.duplicate(bot, 3)
    {:ok, _pid} = Briscolino.GameSupervisor.new_game(players)

    conn
    |> put_flash(:info, "Game created successfully")
    |> redirect(to: "/debug")
  end

  def end_game(conn, params) do
    # End the game with the specified ID.
    pid =
      params["id"]
      |> GameSupervisor.get_game_pid()

    if Process.alive?(pid) do
      Briscolino.GameServer.end_game(pid, true)

      conn
      |> put_flash(:info, "Game ended successfully")
      |> redirect(to: "/debug")
    else
      conn
      |> put_flash(:error, "Game not found")
      |> redirect(to: "/debug")
    end
  end

  def view_game(conn, params) do
    {:ok, state} =
      Briscolino.GameSupervisor.get_game_pid(params["id"])
      |> Briscolino.GameServer.state()

    render(conn, :viewgame, game: state)
  end

  def play_card(conn, params) do
    card_id = params["card"] |> String.to_integer()
    game_id = params["id"]

    pid = GameSupervisor.get_game_pid(game_id)

    case Briscolino.GameServer.play(pid, card_id) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Card played successfully")
        |> redirect(to: "/debug/viewgame/#{game_id}")

      {:error, err} ->
        conn
        |> put_flash(:error, "Error playing card: #{err}")
        |> redirect(to: "/debug/viewgame/#{game_id}")
    end
  end
end
