defmodule BriscolinoWeb.LiveGame.Board do
  alias Briscolino.GameServer
  use BriscolinoWeb, :live_view

  import BriscolinoWeb.LiveGame.GameComponents

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    pid = Briscolino.GameSupervisor.get_game_pid(game_id)
    {:ok, game_info} = Briscolino.GameServer.state(pid)

    socket =
      assign(socket, :game, game_info)
      |> assign(:game_pid, pid)

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
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:game, game}, socket) do
    {:noreply, assign(socket, game: game)}
  end
end
