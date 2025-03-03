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
    <div class="bg-[#0A1117] rounded-lg text-md">
      <div class="flex flex-row items-center flex-wrap p-2">
        <span class="mx-4 flex-grow">Briscola</span>
        <div class="flex flex-row items-center bg-[#1A2127] rounded-lg py-1 px-4 space-x-2">
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
    <div class="flex justify-center items-center space-x-4 text-lg mt-2">
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
    <div class="w-full md:w-128 flex items-start justify-center space-x-4">
      <%= for {card, idx} <- Enum.with_index(@cards) do %>
        <.card
          card={card}
          phx-click={"select-#{idx}"}
          selected={@selected && @selected == idx}
          size="w-24 h-48 md:w-32 md:h-64 shrink-0"
        />
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
    <.trick_area size="h-[295px] w-[588px]">
      <div class="flex items-center justify-center h-full space-x-4 z-10">
        <%= for card <- Enum.reverse(@game.gamestate.trick) do %>
          <.card card={card} />
        <% end %>
      </div>
    </.trick_area>
    """
  end

  @spec trick_mobile(any()) :: Phoenix.LiveView.Rendered.t()
  def trick_mobile(assigns) do
    ~H"""
    <.trick_area size="h-[150px] w-[300px]">
      <div class="flex items-center justify-center h-full -space-x-4 z-10">
        <%= for card <- Enum.reverse(@game.gamestate.trick) do %>
          <.card card={card} size="w-24 h-48" />
        <% end %>
      </div>
    </.trick_area>
    """
  end

  @doc """
  Render a card.
  """
  attr :card, Briscola.Card, required: true
  attr :selected, :boolean, required: false, default: false
  attr :size, :string, required: false, default: "w-32 h-64"
  attr :rest, :global

  def card(assigns) do
    ~H"""
    <div class={["flex items-center", @size]} {@rest}>
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
  Vertical player list
  """
  attr :game, ServerState, required: true
  attr :highlighted, :integer, required: false, default: nil

  def player_list(assigns) do
    ~H"""
    <ul class="pl-4 text-primary_text space-y-4">
      <%= for {idx, info, _playerstate} <- players(@game) do %>
        <li class={[players_turn(@game, idx) && "bg-gray-600", "rounded-md w-full"]}>
          <div class="flex flex-row items-center p-2">
            <div class="flex flex-col flex-grow">
              <.player_name
                name={info.name}
                highlighted={@highlighted == idx}
                class="font-black text-lg"
              />
              <div class="flex flex-row items-center w-full">
                <div id={"player-points-#{idx}"} class="text-md">
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

  @doc """
  Horizontal player list
  """
  attr :game, ServerState, required: true
  attr :highlighted, :integer, required: false, default: nil

  def player_list_mobile(assigns) do
    ~H"""
    <ul class="flex flex-row items-center w-full h-full">
      <%= for {idx, info, _playerstate} <- players(@game) do %>
        <li class={[
          players_turn(@game, idx) && "bg-gray-600",
          "w-full h-full flex flex-col items-center justify-center",
          "rounded-md p-2"
        ]}>
          <.player_name
            name={info.name}
            highlighted={@highlighted == idx}
            class="grow overflow-hidden text-ellipsis break-words line-clamp-2"
          />
          <div id={"player-points-#{idx}"} class="text-md pt-2">
            [ {player_score(@game, idx)} ]
          </div>
        </li>
      <% end %>
    </ul>
    """
  end

  @doc """
  Render the game-end podium
  """
  attr :game, ServerState, required: true

  def podium(assigns) do
    ~H"""
    <.trick_area size="h-[295px] w-[588px]">
      <.podium_ul game={@game} />
    </.trick_area>
    """
  end

  @doc """
  Smaller podium
  """
  attr :game, ServerState, required: true

  def podium_mobile(assigns) do
    ~H"""
    <.trick_area size="h-[150px] w-[300px]">
      <.podium_ul game={@game} />
    </.trick_area>
    """
  end

  @doc """
  Inner unordered list for the podium
  """
  attr :game, ServerState, required: true

  def podium_ul(assigns) do
    ~H"""
    <ul>
      <%= for {place, points, players} <- rankings(@game) do %>
        <li>
          {place + 1}:
          <span class="text-gray-400">({points} pts)</span> {Enum.map(players, fn {_, info, _} ->
            info.name
          end)
          |> Enum.join(", ")}
        </li>
      <% end %>
    </ul>
    """
  end

  @doc """
  Render the center of the board (where the trick / podium go)
  """
  attr :size, :string, required: true
  slot :inner_block, required: true

  def trick_area(assigns) do
    ~H"""
    <div class={[@size, "bg-[url(/images/board.png)] bg-cover flex justify-center items-center"]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Game timer at the top of the screen, with its relevant hook / id
  """
  def game_timer(assigns) do
    ~H"""
    <div id="game-timer" phx-hook="GameTimer" class="h-2.5 bg-blue-600 rounded-full" style="width: 0%">
    </div>
    """
  end

  defp players_turn(state, player_index) do
    state.gamestate.action_on == player_index and
      !Briscola.Game.needs_redeal?(state.gamestate) and
      !Briscola.Game.should_score_trick?(state.gamestate) and
      !Briscola.Game.game_over?(state.gamestate)
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

  defp rankings(%ServerState{} = state) do
    all_players = players(state)

    players_by_scores =
      all_players
      |> Enum.group_by(fn {_, _, game_player} ->
        Briscola.Player.score(game_player)
      end)

    Map.keys(players_by_scores)
    |> Enum.sort()
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.map(fn {score, rank} ->
      players =
        Map.get(players_by_scores, score)
        |> Enum.map(fn {idx, _, _} -> Enum.at(all_players, idx) end)

      {rank, score, players}
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
