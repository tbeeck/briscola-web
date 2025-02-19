defmodule Briscolino.LobbySupervisor do
  alias Briscolino.LobbyServer
  alias Briscolino.ShortId
  alias Briscolino.LobbyServer.LobbyState

  use DynamicSupervisor

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @spec new_lobby() :: {:error, any()} | {:ok, pid()}
  def new_lobby() do
    state = %LobbyState{
      id: ShortId.new(),
      players: []
    }

    case DynamicSupervisor.start_child(__MODULE__, %{
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

    case Registry.lookup(Briscolino.LobbyRegistry, process_name) do
      [] -> nil
      [{pid, _}] -> pid
    end
  end
end
