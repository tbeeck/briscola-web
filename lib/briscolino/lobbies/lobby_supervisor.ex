defmodule Briscolino.LobbySupervisor do
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
end
