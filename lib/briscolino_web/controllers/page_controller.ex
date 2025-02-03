defmodule BriscolinoWeb.PageController do
  use BriscolinoWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def devgame(conn, _params) do
    games =
      Briscolino.GameSupervisor.active_games()
      |> Enum.map(fn pid ->
        %{
          pid: pid,
          name: :undefined,
          state: Briscolino.GameServer.state(pid)
        }
      end)

    new_game_form = %{"players" => 2}
    render(conn, :devgame, new_game: new_game_form, games: games)
  end

  def create_game(conn, params) do
    # Create a new game using the parameters from the form.
    players = Map.get(params, "players", "2") |> String.to_integer()
    {:ok, _pid} = Briscolino.GameSupervisor.new_game(players: players)

    conn
    |> put_flash(:info, "Game created successfully")
    |> redirect(to: "/devgame")
  end

  def end_game(conn, params) do
    IO.inspect(params, label: "end game")
    # End the game with the specified ID.
    pid = Briscolino.GameSupervisor.game_pid(params["id"])

    if Process.alive?(pid) do
      Briscolino.GameServer.end_game(pid, true)

      conn
      |> put_flash(:info, "Game ended successfully")
      |> redirect(to: "/devgame")
    else
      conn
      |> put_flash(:error, "Game not found")
      |> redirect(to: "/devgame")
    end
  end

  def view_game(conn, params) do
    # View a specific game by its ID.
    pid = Briscolino.GameSupervisor.game_pid(params["id"])
    game = Briscolino.GameServer.state(pid)
    render(conn, :viewgame, game: game, game_pid: pid)
  end
end
