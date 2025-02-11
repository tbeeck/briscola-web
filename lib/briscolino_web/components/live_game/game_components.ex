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
            <div class="flex flex-row items-center p-2">
              <img src="/images/card_back.png" class="rounded-full w-12 h-12 m-4" />
              <div class="flex flex-col flex-grow">
                <div>{info.name}</div>
                <div class="flex flex-row">
                  <div class="pl-2 w-4">{player_status(@game, idx)}</div>
                  <div class="pl-4">[ {player_score(@game, idx)} ]</div>
                </div>
              </div>
            </div>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  defp player_status(%ServerState{} = state, player_index) do
    if state.gamestate.action_on == player_index and
         !Briscola.Game.needs_redeal?(state.gamestate) and
         !Briscola.Game.should_score_trick?(state.gamestate) and
         !Briscola.Game.game_over?(state.gamestate) do
      "..."
    else
      ""
    end
  end

  defp player_score(%ServerState{gamestate: game}, player_index),
    do: Briscola.Player.score(Enum.at(game.players, player_index))

  defp players(%ServerState{gamestate: game, playerinfo: players}) do
    players
    |> Enum.with_index()
    |> Enum.zip(game.players)
    |> Enum.map(fn {{info, idx}, game_player} ->
      {idx, info, game_player}
    end)
  end
end
