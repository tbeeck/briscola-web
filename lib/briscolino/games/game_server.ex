defmodule Briscolino.GameServer do
  use GenServer

  alias Briscolino.Presence

  @bot_think_time Application.compile_env(:briscolino, [:game_settings, :bot_think_time])
  @score_time Application.compile_env(:briscolino, [:game_settings, :score_time])
  @redeal_time Application.compile_env(:briscolino, [:game_settings, :redeal_time])
  @player_turn_time Application.compile_env(:briscolino, [:game_settings, :player_turn_time])
  @cleanup_timeout Application.compile_env(:briscolino, [:genserver_settings, :cleanup_timeout])
  @fast_cleanup_timeout Application.compile_env(:briscolino, [
                          :genserver_settings,
                          :fast_cleanup_timeout
                        ])

  defmodule GameClock do
    @type t() :: %__MODULE__{
            timer: reference() | nil
          }
    defstruct [:timer]
  end

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
            id: binary(),
            clock: GameClock.t()
          }
    defstruct [:gamestate, :playerinfo, :id, :clock]
  end

  def game_topic(game_id), do: "gamestate:#{game_id}"
  def game_presence_topic(game_id), do: "game-presence:#{game_id}"

  def start_link(game) do
    GenServer.start_link(__MODULE__, game,
      name: {:via, Registry, {Briscolino.GameRegistry, game_topic(game.id)}}
    )
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

  def end_game(pid) do
    GenServer.stop(pid)
  end

  def new_game(pid) do
    GenServer.call(pid, :new_game)
  end

  @impl true
  def init(state) do
    state = schedule_transition(state)
    {:ok, state, @cleanup_timeout}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, {:ok, state}, state}
    |> with_timeout()
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
    |> with_timeout()
  end

  @impl true
  def handle_call(:new_game, _from, %ServerState{gamestate: game} = state) do
    cond do
      Briscola.Game.game_over?(game) ->
        new_state =
          %ServerState{state | gamestate: Briscola.Game.new(players: length(game.players))}
          |> schedule_transition()
          |> notify()

        {:reply, :ok, new_state}

      true ->
        {:reply, {:error, :game_not_over}, state}
    end
    |> with_timeout()
  end

  @impl true
  def handle_info(:player_timer_expired, %ServerState{gamestate: game} = state) do
    # Play a random card
    random_card_idx = Briscola.Strategy.Random.choose_card(game, game.action_on)
    {:reply, _, new_state, timeout} = handle_call({:play, random_card_idx}, self(), state)
    {:noreply, new_state, timeout}
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

    {:noreply, new_state} |> with_timeout()
  end

  @impl true
  def handle_info(:score, %ServerState{} = state) do
    trick_points = Enum.sum_by(state.gamestate.trick, &Briscola.Card.score/1)

    case Briscola.Game.score_trick(state.gamestate) do
      {:error, _err} ->
        {:noreply, state}

      {:ok, game, winner} ->
        new_state =
          %ServerState{state | gamestate: game}
          |> schedule_transition()
          |> notify()

        notify_trick(state, winner, trick_points)

        {:noreply, new_state}
    end
    |> with_timeout()
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
    |> with_timeout()
  end

  @impl true
  def handle_info(:timeout, %ServerState{} = state) do
    {:stop, :normal, state}
  end

  defp schedule_transition(%ServerState{gamestate: game, clock: clock} = state) do
    case clock.timer do
      nil -> nil
      timer -> Process.cancel_timer(timer)
    end

    timer =
      cond do
        Briscola.Game.should_score_trick?(game) ->
          Process.send_after(self(), :score, @score_time)

        Briscola.Game.needs_redeal?(game) ->
          Process.send_after(self(), :redeal, @redeal_time)

        action_on_ai?(state) && !Briscola.Game.game_over?(game) ->
          Process.send_after(self(), :play_ai, @bot_think_time)

        true ->
          # It's a player's turn -- force a move after turn is over
          Process.send_after(self(), :player_timer_expired, @player_turn_time)
      end

    %ServerState{state | clock: %GameClock{clock | timer: timer}}
  end

  defp action_on_ai?(%ServerState{} = state), do: get_ai_strategy(state) != nil

  defp get_ai_strategy(%ServerState{gamestate: game, playerinfo: players}),
    do: Enum.at(players, game.action_on).ai_strategy

  defp get_play_token(%ServerState{gamestate: game, playerinfo: players}),
    do: Enum.at(players, game.action_on).play_token

  defp notify(state) do
    Phoenix.PubSub.broadcast(Briscolino.PubSub, game_topic(state.id), {:game, state})
    state
  end

  defp notify_trick(state, trick_winner, points) do
    Phoenix.PubSub.broadcast(
      Briscolino.PubSub,
      game_topic(state.id),
      {:trick_scored, trick_winner, points}
    )

    state
  end

  defp players_connected?(%ServerState{} = state) do
    topic = game_presence_topic(state.id)
    Enum.count(Presence.list(topic)) > 0
  end

  defp with_timeout({:reply, reply, state}) do
    cond do
      !players_connected?(state) ->
        {:reply, reply, state, @fast_cleanup_timeout}

      true ->
        {:reply, reply, state, @cleanup_timeout}
    end
  end

  defp with_timeout({:noreply, state}) do
    cond do
      !players_connected?(state) ->
        {:noreply, state, @fast_cleanup_timeout}

      true ->
        {:noreply, state, @cleanup_timeout}
    end
  end
end
