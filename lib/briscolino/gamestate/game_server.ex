defmodule Briscolino.GameServer do
  use GenServer

  defmodule PlayerInfo do
    @type t() :: %__MODULE__{
            session_token: String.t()
          }
    defstruct [:session_token]
  end

  defmodule ServerState do
    @type t() :: %__MODULE__{
            gamestate: Briscola.Game,
            playerinfo: [PlayerInfo.t()]
          }
    defstruct [:gamestate, :playerinfo]
  end

  def start_link(game) do
    GenServer.start_link(__MODULE__, game, [])
  end

  def play(pid, card) do
    GenServer.call(pid, {:play, card})
  end

  def score(pid) do
    GenServer.call(pid, :next_hand)
  end

  def redeal(pid) do
    GenServer.call(pid, :redeal)
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

      {:reply, result} ->
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
    {:reply, state, state}
  end

  @impl true
  def handle_call({:play, index}, _from, state) do
    case Briscola.Game.play(state, index) do
      {:ok, game} -> {:reply, game, game}
      {:error, err} -> {:reply, {:error, err}, state}
    end
  end

  @impl true
  def handle_call(:next_hand, _from, state) do
    case Briscola.Game.score_trick(state) do
      {:error, err} -> {:reply, {:error, err}, state}
      {:ok, game, winner} -> {:reply, {:ok, game, winner}, game}
    end
  end

  @impl true
  def handle_call(:redeal, _from, state) do
    case Briscola.Game.redeal(state) do
      {:error, err} -> {:reply, {:error, err}, state}
      game -> {:reply, :ok, game}
    end
  end

  @impl true
  def handle_call(:result, _from, state) do
    if Briscola.Game.game_over?(state) do
      {:reply, Enum.sort_by(state.players, &Briscola.Player.score(&1), :desc), state}
    else
      {:reply, nil, state}
    end
  end
end
