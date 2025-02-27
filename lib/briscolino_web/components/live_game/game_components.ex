defmodule BriscolinoWeb.LiveGame.GameComponents do
  use Phoenix.Component
  use Gettext, backend: BriscolinoWeb.Gettext

  import BriscolinoWeb.CoreComponents

  alias Briscola.Card
  alias Briscolino.GameServer.ServerState

  @doc """
  Card pile with briscola underneath
  """
  attr :game, ServerState, required: true

  def pile(assigns) do
    ~H"""
    <div>
      <div class="flex justify-center relative">
        <.card_back class="absolute left-1/2 bottom-0 -translate-x-1/2 w-32 rotate-[90deg] -z-10 pointer-events-none select-none" />
        <.card_back class="absolute left-1/2 bottom-0 -translate-x-1/2 w-32 rotate-[94deg] -z-10 pointer-events-none select-none" />
        <.card card={@game.gamestate.briscola} class="justify-center items-center" />
      </div>
      <div class="flex flex-col justify-center items-center w-64">
        <.briscola_badge card={@game.gamestate.briscola} />
        <p class="text-xs">{cards_remaining(@game)}/40 cards remainin</p>
      </div>
    </div>
    """
  end

  @doc """
  Badge displaying the briscola for the game
  """
  attr :card, Card, required: true

  def briscola_badge(assigns) do
    ~H"""
    <div class="bg-gray-900 rounded-lg text-md">
      <div class="flex flex-row items-center flex-wrap p-2">
        <span class="mx-4">Briscola</span>
        <div class="flex flex-row items-center bg-gray-800 rounded-lg py-1 px-4 space-x-2">
          <img src={"/images/cards/fantasy/#{@card.suit}.png"} class="w-4 h-4" />
          <span>{Integer.to_string(@card.rank)}</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Buttons for playing a card / clearing your selection.
  """
  attr :game, ServerState, required: true
  attr :selected, :any, required: true

  def action_panel(assigns) do
    ~H"""
    <div class="flex justify-center items-center space-x-4 text-lg">
      <.pixel_button
        icon="hero-x-mark"
        text_style="text-red-400 hover:text-red-200"
        phx-click="clear-selection"
        disabled={@selected == nil}
      >
        Clear
      </.pixel_button>
      <.pixel_button
        icon="hero-arrow-up-on-square"
        text_style="text-green-400 hover:text-green-200"
        phx-click="play"
        disabled={@selected == nil}
      >
        Play
      </.pixel_button>
    </div>
    """
  end

  @doc """
  Player's hand
  """
  attr :cards, :list, required: true
  attr :selected, :any, required: false, default: nil

  def hand(assigns) do
    ~H"""
    <div class="w-128 flex items-center justify-center space-x-4">
      <%= for {card, idx} <- Enum.with_index(@cards) do %>
        <.card card={card} phx-click={"select-#{idx}"} selected={@selected && @selected == idx} />
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
    <div class="h-[295px] w-[588px] bg-[url(/images/board.png)] bg-cover">
      <div class="flex items-center justify-center h-full space-x-4 z-10">
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
  attr :selected, :boolean, required: false, default: false
  attr :rest, :global

  def card(assigns) do
    ~H"""
    <div class="w-32 h-64 flex items-center" {@rest}>
      <img
        src={"/images/cards/fantasy/#{@card.rank}_#{@card.suit}.png"}
        class={[
          "w-full pointer-events-none select-none",
          @selected == true && "outline outline-2 outline-offset-2 outline-card_highlight rounded-sm"
        ]}
      />
    </div>
    """
  end

  @doc """
  Render face-down card.
  """
  attr :rest, :global

  def card_back(assigns) do
    ~H"""
    <div {@rest}>
      <img src="/images/card_back.png" />
    </div>
    """
  end

  @doc """
  Renders players in the sidebar
  """
  attr :game, ServerState, required: true

  def player_list(assigns) do
    ~H"""
    <ul class="pl-4 text-primary_text space-y-4">
      <%= for {idx, info, _playerstate} <- players(@game) do %>
        <li  id={"player-list-#{idx}"} class={[players_turn(@game, idx) && "bg-gray-600", "rounded-md w-full"]}>
          <div class="flex flex-row items-center p-2">
            <div class="rounded-full w-12 h-12 mr-4 outline flex items-center justify-center">
              Image
            </div>
            <div class="flex flex-col flex-grow">
              <div class="text-md">{info.name}</div>
              <div class="flex flex-row items-center w-full">
                <div class="pl-4 text-md">
                  [ {player_score(@game, idx)} ]
                </div>
              </div>
            </div>
          </div>
        </li>
      <% end %>
    </ul>
    """
  end

  defp players_turn(state, player_index) do
    state.gamestate.action_on == player_index and
      !Briscola.Game.needs_redeal?(state.gamestate) and
      !Briscola.Game.should_score_trick?(state.gamestate) and
      !Briscola.Game.game_over?(state.gamestate)
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

  defp cards_remaining(%ServerState{gamestate: game}) do
    cond do
      length(game.deck.cards) == 0 ->
        0

      true ->
        # Add the briscola if not yet distributed
        length(game.deck.cards) + 1
    end
  end
end
