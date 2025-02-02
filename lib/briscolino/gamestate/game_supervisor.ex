defmodule Briscolino.GameSupervisor do
  use DynamicSupervisor

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def new_game() do
    case DynamicSupervisor.start_child(__MODULE__, %{
           id: :ignored,
           start: {Briscolina.GameServer, :start_link, [[]]}
         }) do
      {:error, error} -> {:error, error}
      {:ok, pid} -> {:ok, pid}
    end
  end
end
