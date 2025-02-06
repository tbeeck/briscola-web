defmodule BriscolinoWeb.DebugGameLive do
  use BriscolinoWeb, :live_view

  def mount(params, _session, socket) do
    pid = Briscolino.GameSupervisor.get_game_pid(params["id"])
    {:ok, game_info} = Briscolino.GameServer.state(pid)

    socket =
      assign(socket, :game, game_info)
      |> assign(:game_pid, pid)

    {:ok, socket}
  end

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
      <div>
        <pre>{inspect(@game, pretty: true)}</pre>
      </div>
    </div>
    """
  end

  def handle_event("play_card", params, socket) do
    card_idx = params["value"] |> String.to_integer()
    Briscolino.GameServer.play(socket.assigns.game_pid, card_idx)
    IO.inspect(socket, pretty: true)

    {:noreply, socket}
  end
end
