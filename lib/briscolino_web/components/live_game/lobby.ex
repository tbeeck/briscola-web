defmodule BriscolinoWeb.LiveGame.Lobby do
  alias Briscolino.LobbyServer
  alias Briscolino.LobbySupervisor
  alias Briscolino.Presence
  use BriscolinoWeb, :live_view

  @impl true
  def mount(%{"id" => lobby_id}, session, socket) do
    socket =
      case LobbySupervisor.get_lobby_pid(lobby_id) do
        nil ->
          put_flash(socket, :error, "Lobby not found")
          |> redirect(to: ~p"/")

        pid ->
          setup_socket(pid, lobby_id, session, socket)
      end

    {:ok, socket}
  end

  def setup_socket(pid, lobby_id, session, socket) do
    player_id = session["session_id"]

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Briscolino.PubSub, LobbyServer.lobby_topic(lobby_id))

      Presence.track(self(), LobbyServer.lobby_presence_topic(lobby_id), player_id, %{
        name: session["username"]
      })

      Process.send_after(self(), :update_lobby, 500)
    end

    socket
    |> assign(:lobby, nil)
    |> assign(:lobby_pid, pid)
    |> assign(:player_id, player_id)
  end

  @impl true
  def handle_info(:update_lobby, socket) do
    {:ok, lobby} = LobbyServer.state(socket.assigns.lobby_pid)
    {:noreply, assign(socket, :lobby, lobby)}
  end

  @impl true
  def handle_info({:lobby, lobby}, socket) do
    IO.inspect("Recieved lobby state change")
    {:noreply, assign(socket, :lobby, lobby)}
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
