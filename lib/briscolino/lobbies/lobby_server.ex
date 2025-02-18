defmodule Briscolino.LobbyServer do
  use GenServer

  @max_players 4

  defmodule LobbyPlayer do
    @type t() :: %__MODULE__{
            id: binary(),
            name: binary(),
            is_ai: false
          }
    defstruct [:id, :name, :is_ai]
  end

  defmodule LobbyState do
    @type t() :: %__MODULE__{
            id: binary(),
            players: [LobbyPlayer.t()]
          }
    defstruct [:id, :players]
  end

  def lobby_topic(lobby_id), do: "lobby:#{lobby_id}"

  def start_link(lobby) do
    GenServer.start_link(__MODULE__, lobby, [])
  end

  @impl true
  def init(arg) do
    {:ok, arg}
  end

  @impl true
  def handle_call({:join, %LobbyPlayer{} = player}, _from, %LobbyState{} = state) do
    if length(state.players) >= @max_players do
      {:reply, {:error, :full}, state}
    else
      state =
        %LobbyState{state | players: state.players ++ [player]}
        |> notify()

      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:leave, player_id}, _from, %LobbyState{players: players} = state) do
    players = Enum.reject(players, fn p -> p.id == player_id end)

    state =
      %LobbyState{state | players: players}
      |> notify()

    {:reply, :ok, state}
  end

  defp notify(state) do
    Phoenix.PubSub.broadcast(Briscolino.PubSub, lobby_topic(state.id), {:lobby, state})
    state
  end
end
