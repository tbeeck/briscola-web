defmodule BriscolinoWeb.LiveGame.Lobby do
  alias BriscolinoWeb.UserSessions
  alias Briscolino.LobbyServer.LobbyPlayer
  use BriscolinoWeb, :live_view

  alias Briscolino.LobbyServer
  alias Briscolino.LobbySupervisor
  alias Briscolino.Presence

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
    end

    socket
    |> assign(:lobby, nil)
    |> assign(:lobby_pid, pid)
    |> assign(:player_id, player_id)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-board w-screen h-screen">
      <p>Player {@player_id}</p>

      <button
        class="w-[175px] h-[42px]
               bg-[url(/images/pixel_button.png)] bg-no-repeat bg-cover space-x-2"
        phx-click="add-ai"
      >
        Add AI
      </button>
      <button
        class="w-[175px] h-[42px]
               bg-[url(/images/pixel_button.png)] bg-no-repeat bg-cover space-x-2"
        phx-click="remove-ai"
      >
        Remove AI
      </button>
      <pre>{inspect(@lobby, pretty: true)}</pre>
    </div>
    """
  end

  @impl true
  def handle_event("add-ai", _params, socket) do
    ai_player =
      %LobbyPlayer{
        id: UserSessions.random_player_id(),
        name: UserSessions.random_username() <> " (AI)",
        is_ai: true
      }
      |> IO.inspect(label: "new ai players")

    socket =
      case LobbyServer.add_player(socket.assigns.lobby_pid, ai_player, socket.assigns.player_id) do
        {:ok, _} -> socket
        {:error, err} -> put_flash(socket, :error, "Error: #{err}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove-ai", _params, socket) do
    socket =
      case LobbyServer.remove_ai(socket.assigns.lobby_pid, socket.assigns.player_id) do
        {:ok, _} -> socket
        {:error, err} -> put_flash(socket, :error, "Error: #{err}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:lobby, lobby}, socket) do
    {:noreply, assign(socket, :lobby, lobby)}
  end
end
