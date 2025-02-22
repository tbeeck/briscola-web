defmodule BriscolinoWeb.LiveGame.Board do
  use BriscolinoWeb, :live_view

  import BriscolinoWeb.LiveGame.GameComponents

  alias Briscolino.GameServer
  alias Briscolino.GameServer.ServerState

  @impl true
  def mount(%{"id" => game_id}, session, socket) do
    socket =
      case Briscolino.GameSupervisor.get_game_pid(game_id) do
        nil ->
          put_flash(socket, :error, "Game not found")
          |> redirect(to: ~p"/")

        pid ->
          setup_socket(pid, session, socket)
      end

    {:ok, socket}
  end

  defp setup_socket(game_pid, session, socket) do
    {:ok, state} = Briscolino.GameServer.state(game_pid)

    socket =
      assign(socket, :game, state)
      |> assign(:game_pid, game_pid)
      |> assign(:player_index, player_index(state, session))
      |> assign(:player_id, session["session_id"])
      |> assign(:selected, nil)
      |> assign(:status_message, "...")

    # Update the status message & timer
    socket =
      assign(socket, :status_message, get_status_message(state, socket))
      |> update_timer(state)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Briscolino.PubSub, GameServer.game_topic(state.id))
    end

    socket
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-board w-screen h-screen">
      <div class="fixed w-64 x-0 y-0 h-full
            flex flex-col my-auto justify-center">
        <.player_list game={@game} />
      </div>

      <div class="absolute w-1/2 top-0 left-1/2 -translate-x-1/2 h-2.5 bg-gray-200 rounded-full">
        <div
          id="game-timer"
          phx-hook="GameTimer"
          class="h-2.5 bg-blue-600 rounded-full"
          style="width: 0%"
        >
        </div>
      </div>

      <div class="flex flex-col justify-center items-center">
        <div class="mt-20">
          <h1 class="text-lg text-gray-200">{@status_message}</h1>
        </div>
        <div class="mt-20">
          <.trick game={@game} />
        </div>
        <%= if @player_index do %>
          <div class="fixed bottom-8 left-1/2 -translate-x-1/2">
            <.hand cards={Enum.at(@game.gamestate.players, @player_index).hand} selected={@selected} />
            <.action_panel game={@game} selected={@selected} />
          </div>
        <% end %>
        <div class="flex flex-col justify-center items-center fixed bottom-0 right-0 mr-8 mb-8">
          <.pile game={@game} />
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:game, %ServerState{} = state}, socket) do
    new_message = get_status_message(state, socket)

    socket =
      socket
      |> assign(:game, state)
      |> assign(:status_message, new_message)
      |> update_timer(state)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:trick_scored, winner}, socket) do
    _who_won = Enum.at(socket.assigns.game.playerinfo, winner).name
    # TODO trigger confetti or something probably client-side
    {:noreply, socket}
  end

  @impl true
  def handle_event("play", _params, socket) do
    socket =
      case(
        Briscolino.GameServer.play(
          socket.assigns.game_pid,
          socket.assigns.selected,
          socket.assigns.player_id
        )
      ) do
        {:ok, _game} -> socket
        {:error, err} -> put_flash(socket, :error, "Error playing card: #{err}")
      end

    {:noreply, assign(socket, :selected, nil)}
  end

  @impl true
  def handle_event("select-0", params, socket), do: select_card(0, params, socket)
  def handle_event("select-1", params, socket), do: select_card(1, params, socket)
  def handle_event("select-2", params, socket), do: select_card(2, params, socket)

  @impl true
  def handle_event("clear-selection", _params, socket),
    do: {:noreply, assign(socket, :selected, nil)}

  def select_card(card_idx, _params, socket) do
    if hand_length(socket) > card_idx do
      {:noreply, assign(socket, :selected, card_idx)}
    else
      {:noreply, socket}
    end
  end

  defp player_index(%ServerState{playerinfo: players}, session) do
    play_token = session["session_id"]
    Enum.find_index(players, fn p -> p.play_token == play_token end)
  end

  defp hand_length(socket) do
    case socket.assigns.player_index do
      nil -> 0
      idx -> length(Enum.at(socket.assigns.game.gamestate.players, idx).hand)
    end
  end

  defp get_status_message(%ServerState{gamestate: game, playerinfo: players}, socket) do
    cond do
      Briscola.Game.should_score_trick?(game) ->
        "Scoring..."

      Briscola.Game.game_over?(game) ->
        "Game over!"

      Briscola.Game.needs_redeal?(game) ->
        "Redealing..."

      game.action_on == socket.assigns.player_index ->
        "Your turn!"

      true ->
        player_name =
          Enum.at(players, game.action_on).name

        "#{player_name} is thinking..."
    end
  end

  defp update_timer(socket, %ServerState{clock: clock}) do
    case clock.timer do
      nil -> socket
      timer -> push_event(socket, "timer", %{"remaining" => Process.read_timer(timer)})
    end
  end
end
