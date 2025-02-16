defmodule BriscolinoWeb.LiveGame.GameComponents do
  use Phoenix.Component

  alias Briscola.Card
  alias Briscolino.GameServer.ServerState
  use Gettext, backend: BriscolinoWeb.Gettext

  @doc """
  Card pile with briscola underneath
  """
  attr :game, ServerState, required: true

  def pile(assigns) do
    ~H"""
    <div class="flex flex-col justify-center items-center fixed bottom-0 right-0 ml-4 mb-4">
      <div class="flex justify-center relative">
        <.card_back class="absolute left-1/2 top-0 -translate-x-1/2 w-32 rotate-[90deg]" />
        <.card_back class="absolute left-1/2 top-0 -translate-x-1/2 w-32 rotate-[94deg]" />
        <.card card={@game.gamestate.briscola} class="justify-center items-center z-10" />
      </div>
      <div class="flex justify-center w-64">
        <.briscola_badge card={@game.gamestate.briscola} />
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
    <div class="bg-gray-900 rounded-lg text-white text-md">
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
      <button
        class="w-[175px] h-[42px]
               bg-[url(/images/pixel_button.png)] bg-no-repeat bg-cover space-x-2"
        phx-click="clear-selection"
        disabled={@selected == nil}
      >
        <span class="text-gray-400">[ X ]</span>
        <span class="disabled:text-gray-100 text-red-100">Clear</span>
      </button>
      <button
        class="w-[175px] h-[42px]
               bg-[url(/images/pixel_button.png)] bg-no-repeat bg-cover space-x-2"
        phx-click="play"
        disabled={@selected == nil}
      >
        <span class="text-gray-400">[ <span class="text-xl">↦</span> ]</span>
        <span class="text-green-100">Play</span>
      </button>
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
    <div class="relative w-128 flex flex-wrap items-center justify-center space-x-4">
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
    <div class="relative h-64 w-128">
      <div class="absolute inset-0 flex justify-center items-center">
        <img src="/images/board.png" class="-z-1"/>
      </div>
      <div class="flex flex-wrap items-center justify-center h-full space-x-4 z-1">
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
    <div class={["w-32", "h-64"]} {@rest}>
      <img
        src={"/images/cards/fantasy/#{@card.rank}_#{@card.suit}.png"}
        class={[
          "w-full",
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
    <div id="sidebar" class="fixed w-64 x-0 y-0 h-full
            flex flex-col my-auto justify-center">
      <ul class="pl-4 text-white">
        <%= for {idx, info, _playerstate} <- players(@game) do %>
          <li class={[players_turn(@game, idx) && "bg-gray-600", "rounded-md"]}>
            <div class="flex flex-row items-center p-2">
              <img src="/images/card_back.png" class="rounded-full w-12 h-12 m-2 mr-4" />
              <div class="flex flex-col flex-grow">
                <div class="text-lg">{info.name}</div>
                <div class={["flex flex-row items-center"]}>
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

  defp players_turn(state, player_index) do
    state.gamestate.action_on == player_index and
      !Briscola.Game.needs_redeal?(state.gamestate) and
      !Briscola.Game.should_score_trick?(state.gamestate) and
      !Briscola.Game.game_over?(state.gamestate)
  end

  defp player_status(%ServerState{} = state, player_index) do
    if players_turn(state, player_index) do
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
