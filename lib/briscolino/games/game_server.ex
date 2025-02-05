defmodule Briscolino.GameServer do
  use GenServer

  defmodule PlayerInfo do
    @type t() :: %__MODULE__{
            session_token: String.t(),
            is_ai: boolean(),
            name: String.t()
          }
    defstruct [:session_token, :is_ai, :name]
  end

  defmodule ServerState do
    @type t() :: %__MODULE__{
            gamestate: Briscola.Game.t(),
            playerinfo: [PlayerInfo.t()],
            id: binary()
          }
    defstruct [:gamestate, :playerinfo, :id]
  end

  def start_link(game) do
    GenServer.start_link(__MODULE__, game, [])
  end

  def play(pid, card) do
    GenServer.call(pid, {:play, card})
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
  def init(game) do
    {:ok, game}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:play, index}, _from, state) do
    case Briscola.Game.play(state.gamestate, index) do
      {:ok, game} ->
        if Briscola.Game.should_score_trick?(game) do
          Process.send_after(self(), :score, 1000)
        end

        {:reply, {:ok, game}, %ServerState{state | gamestate: game}}

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
  def handle_info(:score, state) do
    case Briscola.Game.score_trick(state.gamestate) do
      {:error, _err} ->
        {:noreply, state}

      {:ok, game, _winner} ->
        Process.send_after(self(), :redeal, 2000)
        {:noreply, %ServerState{state | gamestate: game}}
    end
  end

  @impl true
  def handle_info(:redeal, state) do
    case Briscola.Game.redeal(state.gamestate) do
      {:error, _err} -> {:noreply, state}
      game -> {:noreply, %ServerState{state | gamestate: game}}
    end
  end
end
