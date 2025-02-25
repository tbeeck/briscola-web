defmodule Briscolino.LobbySupervisor do
  use Horde.DynamicSupervisor

  alias Briscolino.LobbyServer
  alias Briscolino.ShortId
  alias Briscolino.LobbyServer.LobbyState

  @impl true
  def init(_) do
    Horde.DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_link(arg) do
    Horde.DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @spec new_lobby() :: {:error, any()} | {:ok, pid()}
  def new_lobby() do
    state = %LobbyState{
      id: ShortId.new(),
      players: []
    }

    case Horde.DynamicSupervisor.start_child(__MODULE__, %{
           id: :ignored,
           restart: :transient,
           start: {Briscolino.LobbyServer, :start_link, [state]}
         }) do
      {:error, error} -> {:error, error}
      {:ok, pid} -> {:ok, pid}
    end
  end

  @spec get_lobby_pid(binary()) :: pid() | nil
  def get_lobby_pid(lobby_id) do
    process_name = LobbyServer.lobby_topic(lobby_id)

    case Horde.Registry.lookup(Briscolino.LobbyRegistry, process_name) do
      [] -> nil
      [{pid, _}] -> pid
    end
  end

  @spec active_lobbies() :: %{binary() => pid()}
  def active_lobbies() do
    Horde.DynamicSupervisor.which_children(__MODULE__)
    |> Stream.filter(&match?({_, _pid, :worker, [LobbyServer]}, &1))
    |> Stream.map(fn {_, pid, _, _} -> pid end)
    |> Enum.to_list()
    |> Stream.map(&Task.async(fn -> {&1, LobbyServer.state(&1)} end))
    |> Enum.map(&Task.await/1)
    |> Enum.reduce(%{}, fn {pid, {:ok, state}}, acc ->
      Map.put(acc, state.id, pid)
    end)
  end

  @spec active_lobby_pids() :: [pid()]
  def active_lobby_pids() do
    Horde.DynamicSupervisor.which_children(__MODULE__)
    |> Stream.filter(&match?({_, _pid, :worker, [LobbyServer]}, &1))
    |> Stream.map(fn {_, pid, _, _} -> pid end)
    |> Enum.to_list()
  end
end
