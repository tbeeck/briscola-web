defmodule BriscolinoWeb.LiveGame.Lobby do
  use BriscolinoWeb, :live_view

  @impl true
  def mount(%{"id" => lobby_id}, session, socket) do
    socket =
      socket
      |> assign(:lobby_id, lobby_id)
      |> assign(:player_id, session["session_id"])

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-board w-screen h-screen">
      <p>Lobby {@lobby_id}</p>
      <p>Player {@player_id}</p>
    </div>
    """
  end
end
