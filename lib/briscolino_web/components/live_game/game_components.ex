defmodule BriscolinoWeb.LiveGame.GameComponents do
  use Phoenix.Component

  alias Briscolino.GameServer.ServerState
  use Gettext, backend: BriscolinoWeb.Gettext

  @doc """
  Player's hand
  """
  attr :cards, :list, required: true

  def hand(assigns) do
    ~H"""
    <div class="relative h-64 w-128 flex flex-wrap items-center justify-center">
      <%= for {card, idx} <- Enum.with_index(@cards) do %>
        <.card card={card} phx-click={"play-#{idx}"} />
      <% end %>
    </div>
    """
  end

  @doc """
  Render the trick pile
  """
  attr :game, ServerState, required: true
  attr :rest, :global

  def trick(assigns) do
    ~H"""
    <div class="relative h-64 w-128">
      <div class="absolute inset-0 flex justify-center items-center -z-10">
        <img src="/images/board.png" class="w-128 h-32" />
      </div>
      <div class="flex flex-wrap items-center justify-center h-full space-x-4">
        <%= for card <- Enum.reverse(@game.gamestate.trick) do %>
          <.card card={card} />
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Render a card.
  """
  attr :card, Briscola.Card, required: true
  attr :rest, :global

  def card(assigns) do
    ~H"""
    <div class="w-12 h-24 justify-center border" {@rest}>
      <p>{@card.rank} of {@card.suit}</p>
    </div>
    """
  end

  @doc """
  Renders players in the sidebar
  """
  attr :game, ServerState, required: true

  def player_list(assigns) do
    ~H"""
    <div id="sidebar" class="fixed w-64 x-0 y-0 h-full
            flex flex-col my-auto justify-center">
      <ul class="bg-gray-100 rounded-xl pl-4">
        <%= for {idx, info, _playerstate} <- players(@game) do %>
          <li>
            <div class="flex flex-row items-center p-2">
              <img src="/images/card_back.png" class="rounded-full w-12 h-12 m-2 mr-4" />
              <div class="flex flex-col flex-grow">
                <div class="text-lg">{info.name}</div>
                <div class="flex flex-row items-center">
                  {player_status(@game, idx)}
                  <div class="pl-4 text-md">
                    [ {player_score(@game, idx)} ]
                  </div>
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
      assigns = %{}

      ~H"""
      <.animated_elipsis />
      """
    else
      ""
    end
  end

  def animated_elipsis(assigns) do
    ~H"""
    <div class="w-auto flex flex-row items-center">
      <div class="bg-gray-500 w-2 h-2" />
      <div class="bg-gray-500 w-2 h-2 ml-2" />
      <div class="bg-gray-500 w-2 h-2 ml-2" />
    </div>
    """
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
