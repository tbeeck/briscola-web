defmodule Briscolino.GameServer do
  use GenServer

  defmodule PlayerInfo do
    @type t() :: %__MODULE__{
            play_token: String.t(),
            ai_strategy: nil | module(),
            name: String.t()
          }
    defstruct [:play_token, :ai_strategy, :name]
  end

  defmodule ServerState do
    @type t() :: %__MODULE__{
            gamestate: Briscola.Game.t(),
            playerinfo: [PlayerInfo.t()],
            id: binary()
          }
    defstruct [:gamestate, :playerinfo, :id]
  end

  def game_topic(game_id), do: "gamestate:#{game_id}"

  def start_link(game) do
    GenServer.start_link(__MODULE__, game, [])
  end

  def play(pid, card) do
    GenServer.call(pid, {:play, card})
  end

  def play(pid, card, play_token) do
    required_token =
      state(pid)
      |> elem(1)
      |> get_play_token()

    case required_token do
      ^play_token ->
        play(pid, card)

      _ ->
        {:error, :not_your_turn}
    end
  end

  def state(pid) do
    GenServer.call(pid, :state)
  end

  def end_game(pid, force \\ false) do
    case GenServer.call(pid, :result) do
      nil ->
        if force do
          GenServer.stop(pid)
          []
        else
          nil
        end

      result ->
        GenServer.stop(pid)
        result
    end
  end

  @impl true
  def init(state) do
    schedule_transition(state)
    {:ok, state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:play, index}, _from, state) do
    case Briscola.Game.play(state.gamestate, index) do
      {:ok, game} ->
        new_state =
          %ServerState{state | gamestate: game}
          |> schedule_transition()
          |> notify()

        {:reply, {:ok, game}, new_state}

      {:error, err} ->
        {:reply, {:error, err}, state}
    end
  end

  @impl true
  def handle_call(:result, _from, state) do
    if Briscola.Game.game_over?(state.gamestate) do
      {:reply, Enum.sort_by(state.gamestate.players, &Briscola.Player.score(&1), :desc), state}
    else
      {:reply, nil, state}
    end
  end

  @impl true
  def handle_info(:play_ai, state) do
    strategy = get_ai_strategy(state)
    card = strategy.choose_card(state.gamestate, state.gamestate.action_on)
    {:ok, game} = Briscola.Game.play(state.gamestate, card)

    new_state =
      %ServerState{state | gamestate: game}
      |> schedule_transition()
      |> notify()

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:score, state) do
    case Briscola.Game.score_trick(state.gamestate) do
      {:error, _err} ->
        {:noreply, state}

      {:ok, game, winner} ->
        new_state =
          %ServerState{state | gamestate: game}
          |> schedule_transition()
          |> notify()

        notify_trick(state, winner)

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:redeal, state) do
    case Briscola.Game.redeal(state.gamestate) do
      {:error, _err} ->
        {:noreply, state}

      game ->
        new_state =
          %ServerState{state | gamestate: game}
          |> schedule_transition()
          |> notify()

        {:noreply, new_state}
    end
  end

  defp schedule_transition(%ServerState{gamestate: game} = state) do
    cond do
      Briscola.Game.should_score_trick?(game) ->
        Process.send_after(self(), :score, 1000)

      Briscola.Game.needs_redeal?(game) ->
        Process.send_after(self(), :redeal, 2000)

      action_on_ai(state) && !Briscola.Game.game_over?(game) ->
        Process.send_after(self(), :play_ai, 1000)

      true ->
        nil
    end

    state
  end

  defp action_on_ai(%ServerState{} = state), do: get_ai_strategy(state) != nil

  defp get_ai_strategy(%ServerState{gamestate: game, playerinfo: players}),
    do: Enum.at(players, game.action_on).ai_strategy

  defp get_play_token(%ServerState{gamestate: game, playerinfo: players}),
    do: Enum.at(players, game.action_on).play_token

  defp notify(state) do
    Phoenix.PubSub.broadcast(Briscolino.PubSub, game_topic(state.id), {:game, state})
    state
  end

  defp notify_trick(state, trick_winner) do
    Phoenix.PubSub.broadcast(
      Briscolino.PubSub,
      game_topic(state.id),
      {:trick_scored, trick_winner}
    )

    state
  end
end
