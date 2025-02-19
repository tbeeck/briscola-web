defmodule BriscolinoWeb.LiveGame.Lobby do
  alias Briscolino.LobbyServer.LobbyPlayer
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

    lobby_pid = socket.assigns.lobby_pid
    player_id = socket.assigns.player_id
    player = %LobbyPlayer{
      id: player_id,
      name: "Player",
      is_ai: false
    }
    LobbyServer.join(lobby_pid, player)
    {:ok, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    # Leave the lobby
    lobby_pid = socket.assigns.lobby_pid
    player_id = socket.assigns.player_id
    LobbyServer.leave(lobby_pid, player_id)
  end

  def setup_socket(pid, session, socket) do
    {:ok, lobby} = LobbyServer.state(pid)

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
