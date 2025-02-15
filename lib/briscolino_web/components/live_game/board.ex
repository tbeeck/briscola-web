defmodule BriscolinoWeb.LiveGame.Board do
  use BriscolinoWeb, :live_view

  import BriscolinoWeb.LiveGame.GameComponents

  alias Briscolino.GameServer
  alias Briscolino.GameServer.ServerState

  @impl true
  def mount(%{"id" => game_id}, session, socket) do
    pid = Briscolino.GameSupervisor.get_game_pid(game_id)
    {:ok, game_info} = Briscolino.GameServer.state(pid)

    socket =
      assign(socket, :game, game_info)
      |> assign(:game_pid, pid)
      |> assign(:player_index, player_index(game_info, session))
      |> assign(:player_id, session["session_id"])
      |> assign(:selected, nil)

    Phoenix.PubSub.subscribe(Briscolino.PubSub, GameServer.game_topic(game_id))
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-board">
      <.player_list game={@game} />
      <div class="relative pl-16 w-screen h-screen">
        <div class="flex justify-center items-center">
          <.card_back class="absolute w-32 rotate-90" />
          <.card card={@game.gamestate.briscola} class="justify-center items-center z-10" />
        </div>
        <.trick game={@game} />
        <%= if @player_index do %>
          <.hand cards={Enum.at(@game.gamestate.players, @player_index).hand} selected={@selected} />
        <% end %>
        <.action_panel game={@game} selected={@selected} />
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:game, game}, socket) do
    {:noreply, assign(socket, game: game)}
  end

  @impl true
  def handle_info({:trick_scored, winner}, socket) do
    who_won = Enum.at(socket.assigns.game.playerinfo, winner).name

    socket =
      socket
      |> put_flash(:info, "#{who_won} won the trick.")

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
end
