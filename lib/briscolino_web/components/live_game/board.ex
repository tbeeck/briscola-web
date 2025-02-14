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

    Phoenix.PubSub.subscribe(Briscolino.PubSub, GameServer.game_topic(game_id))
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.player_list game={@game} />
      <div class="pl-64 w-screen h-screen">
        <.trick game={@game} />
        <%= if @player_index do %>
          <.hand cards={Enum.at(@game.gamestate.players, @player_index).hand} />
        <% end %>
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
  def handle_event("play-0", params, socket), do: play_card(0, params, socket)
  def handle_event("play-1", params, socket), do: play_card(1, params, socket)
  def handle_event("play-2", params, socket), do: play_card(2, params, socket)

  defp play_card(index, _params, socket) do
    socket =
      case(
        Briscolino.GameServer.play(socket.assigns.game_pid, index, socket.assigns.player_id)
      ) do
        {:ok, _game} -> put_flash(socket, :info, "Played card #{index}")
        {:error, err} -> put_flash(socket, :error, "Error playing card: #{err}")
      end

    {:noreply, socket}
  end

  defp player_index(%ServerState{playerinfo: players}, session) do
    play_token = session["session_id"]
    Enum.find_index(players, fn p -> p.play_token == play_token end)
  end
end
