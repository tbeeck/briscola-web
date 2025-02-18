defmodule Briscolino.GameSupervisor do
  use DynamicSupervisor

  alias Briscolino.GameServer.GameClock
  alias Briscolino.GameServer
  alias Briscolino.GameServer.ServerState
  alias Briscolino.GameServer.PlayerInfo

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @spec new_game([PlayerInfo.t()]) :: {:error, any()} | {:ok, pid()}
  def new_game(players) do
    game_id = Briscolino.ShortId.new()
    gamestate = Briscola.Game.new(players: Enum.count(players))

    state = %ServerState{
      playerinfo: players,
      gamestate: gamestate,
      id: game_id,
      clock: %GameClock{timer: nil}
    }

    make_game(state)
  end

  @spec new_ai_game() :: {:error, any()} | {:ok, pid()}
  def new_ai_game() do
    players = 4
    game_id = Briscolino.ShortId.new()
    gamestate = Briscola.Game.new(players: players)

    players =
      List.duplicate(
        %PlayerInfo{name: "AI Player", ai_strategy: Briscola.Strategy.Random},
        players
      )

    state = %ServerState{
      playerinfo: players,
      gamestate: gamestate,
      id: game_id,
      clock: %GameClock{timer: nil}
    }

    make_game(state)
  end

  @spec make_game(ServerState.t()) :: {:error, any()} | {:ok, pid()}
  defp make_game(%ServerState{} = state) do
    case DynamicSupervisor.start_child(__MODULE__, %{
           id: :ignored,
           restart: :transient,
           start: {Briscolino.GameServer, :start_link, [state]}
         }) do
      {:error, error} -> {:error, error}
      {:ok, pid} -> {:ok, pid}
    end
  end

  @spec active_games() :: %{binary() => pid()}
  def active_games() do
    DynamicSupervisor.which_children(__MODULE__)
    |> Stream.filter(&match?({_, _pid, :worker, [GameServer]}, &1))
    |> Stream.map(fn {_, pid, _, _} -> pid end)
    |> Stream.map(&Task.async(fn -> {&1, GameServer.state(&1)} end))
    |> Enum.map(&Task.await/1)
    |> Enum.reduce(%{}, fn {pid, {:ok, state}}, acc ->
      Map.put(acc, state.id, pid)
    end)
  end

  @spec get_game_pid(binary()) :: pid() | nil
  def get_game_pid(game_id) do
    DynamicSupervisor.which_children(__MODULE__)
    |> Stream.filter(&match?({_, _pid, :worker, [GameServer]}, &1))
    |> Stream.map(fn {_, pid, _, _} -> pid end)
    |> Enum.find(fn pid ->
      {:ok, state} = GameServer.state(pid)
      state.id == game_id
    end)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
