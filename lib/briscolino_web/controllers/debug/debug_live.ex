defmodule BriscolinoWeb.DebugGameLive do
  alias Briscolino.GameServer
  use BriscolinoWeb, :live_view

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    pid = Briscolino.GameSupervisor.get_game_pid(game_id)
    {:ok, game_info} = Briscolino.GameServer.state(pid)

    socket =
      assign(socket, :game, game_info)
      |> assign(:game_pid, pid)

    # Subscribe to updates
    Phoenix.PubSub.subscribe(Briscolino.PubSub, GameServer.game_topic(game_id))
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-row">
      <div>
        <.simple_form for={%{}} method="delete" action={"/debug/endgame/#{@game.id}"}>
          <:actions>
            <.button class="bg-brand hover:bg-brand/80" type="submit">End Game</.button>
          </:actions>
        </.simple_form>
        <%= for idx <- 0..2 do %>
          <.button phx-click="play_card" value={idx}>
            Play Card {idx}
          </.button>
        <% end %>
      </div>

      <div class="mt-4 flex">
        <%= for {player, idx} <- Enum.with_index(@game.playerinfo) do %>
          <div class="m-1 p-1 size-auto shadow">
            <h2>{idx + 1}: {player.name}</h2>
            <%= if @game.gamestate.action_on == idx do %>
              <p>Action</p>
            <% end %>
            <h3>Hand:</h3>
            <div>
              <%= for card <- Enum.at(@game.gamestate.players, idx).hand do %>
                <p>{card.rank} of {card.suit}</p>
              <% end %>
            </div>

            <h3>Score: {Briscola.Player.score(Enum.at(@game.gamestate.players, idx))}</h3>
          </div>
        <% end %>
      </div>
    </div>
    <div>
      <pre>{inspect(@game, pretty: true)}</pre>
    </div>
    """
  end

  @impl true
  def handle_event("play_card", params, socket) do
    card_idx = params["value"] |> String.to_integer()

    socket =
      case(Briscolino.GameServer.play(socket.assigns.game_pid, card_idx)) do
        {:ok, _game} -> put_flash(socket, :info, "Played card #{card_idx}")
        {:error, err} -> put_flash(socket, :error, "Error playing card: #{err}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:game, game}, socket) do
    {:noreply, assign(socket, game: game)}
  end
end
