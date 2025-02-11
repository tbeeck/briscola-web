defmodule BriscolinoWeb.LiveGame.GameComponents do
  use Phoenix.Component

  alias Briscolino.GameServer.PlayerInfo
  alias Briscolino.GameServer.ServerState
  use Gettext, backend: BriscolinoWeb.Gettext

  @doc """
  Renders players in the sidebar
  """
  attr :game, ServerState, required: true

  def player_list(assigns) do
    ~H"""
    <div id="sidebar" class="fixed w-64 x-0 y-0 h-full
            flex flex-col my-auto justify-center">
      <ul class="bg-gray-100 rounded-xl pl-4">
        <%= for {idx, info, playerstate} <- players(@game) do %>
          <li>
            <div>{info.name}{thinking(@game, idx)}</div>
            <div class="h-8">
              {List.duplicate("🃏", length(playerstate.hand))}
            </div>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  defp thinking(%ServerState{} = state, player_index) do
    if state.gamestate.action_on == player_index and
         !Briscola.Game.needs_redeal?(state.gamestate) and
         !Briscola.Game.should_score_trick?(state.gamestate) and
         !Briscola.Game.game_over?(state.gamestate) do
      " (thinking...)"
    else
      ""
    end
  end

  defp players(%ServerState{gamestate: game, playerinfo: players} = _state) do
    players
    |> Enum.with_index()
    |> Enum.zip(game.players)
    |> Enum.map(fn {{info, idx}, game_player} ->
      {idx, info, game_player}
    end)
  end
end
