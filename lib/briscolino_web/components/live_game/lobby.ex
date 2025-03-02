defmodule BriscolinoWeb.LiveGame.Lobby do
  alias Briscolino.LobbyServer.LobbyState
  use BriscolinoWeb, :live_view

  import BriscolinoWeb.LiveGame.LobbyComponents

  alias BriscolinoWeb.UserSessions
  alias Briscolino.LobbyServer.LobbyPlayer
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

    {:ok, lobby} =
      LobbySupervisor.get_lobby_pid(lobby_id)
      |> LobbyServer.state()

    socket
    |> assign(:device_type, UserSessions.get_device(session))
    |> assign(:lobby, lobby)
    |> assign(:leader, LobbyServer.find_leader(lobby))
    |> assign(:lobby_pid, pid)
    |> assign(:player_id, player_id)
    |> assign(:player_index, player_index(socket, lobby))
    |> update_page_title(lobby)
  end

  @impl true
  def render(assigns) do
    case assigns.device_type do
      :mobile -> render_mobile(assigns)
      :desktop -> render_desktop(assigns)
    end
  end

  def render_desktop(assigns) do
    ~H"""
    <div class="bg-board w-screen h-screen">
      <div class="fixed w-64 x-0 y-0 h-full
                  flex flex-col my-auto justify-center">
        <.lobby_player_list lobby={@lobby} highlighted={@player_index} />
      </div>
      <div class="flex flex-col justify-center items-center">
        <div class="mt-[10%]">
          <%= if @leader do %>
            <h1 class="text-2xl">{@leader.name}'s Lobby</h1>
          <% end %>
        </div>
        <div class="flex flex-col items-center mt-[10%] space-y-4">
          <div class="flex flex-row space-x-4">
            <.pixel_button icon="hero-plus" phx-click="add-ai">
              Add AI
            </.pixel_button>
            <.pixel_button icon="hero-minus" phx-click="remove-ai">
              Remove AI
            </.pixel_button>
          </div>
          <div class="flex flex-row space-x-4">
            <.pixel_button icon="hero-link" phx-click={JS.dispatch("phx:copy-link")}>
              Copy Link
            </.pixel_button>
            <.pixel_button icon="hero-play" phx-click="start-game">
              Start Game
            </.pixel_button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render_mobile(assigns) do
    ~H"""
    <div class="bg-board w-screen h-screen">
      <div class="flex flex-col justify-center items-center">
        <div class="mt-[10%]">
          <%= if @leader do %>
            <h1 class="text-2xl">{@leader.name}'s Lobby</h1>
          <% end %>
        </div>
        <div class="flex flex-col mt-16 justify-center">
          <.lobby_player_list lobby={@lobby} highlighted={@player_index} />
        </div>
      </div>
      <div class="fixed bottom-0 left-1/2 -translate-x-1/2 mb-8
                  flex flex-col items-center space-y-4">
        <div class="flex flex-row space-x-4">
          <.pixel_button icon="hero-plus" phx-click="add-ai">
            Add AI
          </.pixel_button>
          <.pixel_button icon="hero-minus" phx-click="remove-ai">
            Remove AI
          </.pixel_button>
        </div>
        <div class="flex flex-row space-x-4">
          <.pixel_button icon="hero-link" phx-click={JS.dispatch("phx:copy-link")}>
            Copy Link
          </.pixel_button>
          <.pixel_button icon="hero-play" phx-click="start-game">
            Start Game
          </.pixel_button>
        </div>
      </div>
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
  def handle_event("start-game", _params, socket) do
    socket =
      case LobbyServer.start_game(socket.assigns.lobby_pid, socket.assigns.player_id) do
        {:ok, _pid} ->
          # Wait for "game_start" event to hit, then redirect
          socket

        {:error, err} ->
          put_flash(socket, :error, "Error: #{err}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:lobby, lobby}, socket) do
    socket =
      socket
      |> assign(:lobby, lobby)
      |> assign(:leader, LobbyServer.find_leader(lobby))
      |> assign(:player_index, player_index(socket.assigns.player_id, lobby))
      |> update_page_title(lobby)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_start, game_id}, socket) do
    {:noreply, redirect(socket, to: ~p"/game/#{game_id}")}
  end

  defp update_page_title(socket, %LobbyState{players: players}) do
    assign(socket, :page_title, "#{length(players)}/4 players")
  end

  defp player_index(player_id, %LobbyState{players: players}),
    do: Enum.find_index(players, fn p -> p.id == player_id end)
end
