defmodule BriscolinoWeb.LiveGame.Lobby do
  alias Briscolino.LobbyServer
  alias Briscolino.LobbySupervisor
  use BriscolinoWeb, :live_view

  @impl true
  def mount(%{"id" => lobby_id}, session, socket) do
    socket =
      case LobbySupervisor.get_lobby_pid(lobby_id) do
        nil ->
          put_flash(socket, :error, "Lobby not found")
          |> redirect(to: ~p"/")

        pid ->
          setup_socket(pid, session, socket)
      end

    {:ok, socket}
  end

  def setup_socket(pid, session, socket) do
    lobby = LobbyServer.state(pid)

    socket
    |> assign(:lobby_pid, pid)
    |> assign(:lobby, lobby)
    |> assign(:player_id, session["session_id"])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-board w-screen h-screen">
      <p>Player {@player_id}</p>
      <pre>{inspect(@lobby, pretty: true)}</pre>
    </div>
    """
  end
end
