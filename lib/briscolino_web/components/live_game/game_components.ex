defmodule BriscolinoWeb.LiveGame.GameComponents do
  use Phoenix.Component

  alias Briscolino.GameServer.ServerState
  alias Phoenix.LiveView.JS
  use Gettext, backend: BriscolinoWeb.Gettext

  @doc """
  Renders the list of players
  """
  attr :game, ServerState, required: true

  def player_list(assigns) do
    ~H"""
    <div class="container">
      <ul>
        <%= for {idx, info, playerstate} <- players(@game) do %>
          <li> {info.name} {thinking(@game, idx)}</li>
        <% end %>
      </ul>
    </div>
    """
  end

  def thinking(%ServerState{} = state, player_index) do
    if state.gamestate.action_on == player_index do
      "(thinking...)"
    else
      ""
    end
  end

  def players(%ServerState{gamestate: game, playerinfo: players} = _state) do
    players
    |> Enum.with_index()
    |> Enum.zip(game.players)
    |> Enum.map(fn {{info, idx}, game_player} ->
      {idx, info, game_player}
    end)
  end
end
