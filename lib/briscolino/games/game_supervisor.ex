defmodule Briscolino.GameSupervisor do
  use DynamicSupervisor

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def new_game(players, opts \\ []) do
    game = Briscola.Game.new(opts)

    case DynamicSupervisor.start_child(__MODULE__, %{
           id: :ignored,
           start: {Briscolino.GameServer, :start_link, [game]}
         }) do
      {:error, error} -> {:error, error}
      {:ok, pid} -> {:ok, pid}
    end
  end

  def active_games() do
    # Map to just the PIDs of workers
    Enum.map(DynamicSupervisor.which_children(__MODULE__), fn tuple ->
      case tuple do
        {:undefined, pid, _, _} -> pid
      end
    end)
  end

  def game_id(pid) do
    # Turn PID into a string for easy comparison
    :erlang.term_to_binary(pid)
  end

  def game_pid(id) do
    # Turn string back into PID
    :erlang.binary_to_term(id)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
