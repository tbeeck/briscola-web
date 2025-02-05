defmodule BriscolinoWeb.DebugController do
  alias Briscolino.GameSupervisor
  alias Briscolino.GameServer
  use BriscolinoWeb, :controller

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
    {:ok, _pid} = Briscolino.GameSupervisor.new_game(players: players)

    conn
    |> put_flash(:info, "Game created successfully")
    |> redirect(to: "/debug")
  end

  def end_game(conn, params) do
    # End the game with the specified ID.
    pid =
      params["id"]
      |> GameSupervisor.get_game_pid()
      |> IO.inspect()

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
end
