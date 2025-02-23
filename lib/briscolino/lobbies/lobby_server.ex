defmodule Briscolino.LobbyServer do
  use GenServer
  alias Phoenix.PubSub

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
  def lobby_presence_topic(lobby_id), do: "lobby-presence:#{lobby_id}"

  def start_link(%LobbyState{} = lobby) do
    GenServer.start_link(__MODULE__, lobby,
      name: {:via, Registry, {Briscolino.LobbyRegistry, lobby_topic(lobby.id)}}
    )
  end

  def state(pid) do
    GenServer.call(pid, :state)
  end

  def join(pid, %LobbyPlayer{} = player) do
    GenServer.call(pid, {:join, player})
  end

  def add_player(pid, %LobbyPlayer{} = player, initiator_id) do
    GenServer.call(pid, {:join, player, initiator_id})
  end

  def leave(pid, player_id) do
    GenServer.call(pid, {:leave, player_id})
  end

  @impl true
  def init(%LobbyState{} = arg) do
    PubSub.subscribe(Briscolino.PubSub, lobby_presence_topic(arg.id))
    {:ok, arg}
  end

  @impl true
  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %LobbyState{} = socket
      ) do
    joined_players =
      Enum.map(joins, fn {player_id, %{metas: metas}} ->
        %LobbyPlayer{
          id: player_id,
          name: Map.get(List.first(metas), :name, "Who is this?")
        }
      end)

    leaving_players = Map.keys(leaves)

    new_players =
      Enum.concat(socket.players, joined_players)
      |> Enum.reject(fn p -> Enum.member?(leaving_players, p.id) end)
      |> Enum.uniq_by(fn p -> p.id end)
      |> Enum.slice(0..3)

    new_state =
      %LobbyState{socket | players: new_players}
      |> notify()

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:state, _from, %LobbyState{} = state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:join, %LobbyPlayer{} = player, initiator_id}, from, %LobbyState{} = state) do
    leader = find_leader(state)
    leader_id = leader.id

    case initiator_id do
      ^leader_id -> handle_call({:join, player}, from, state)
      _ -> {:reply, {:error, :not_leader}, state}
    end
  end

  @impl true
  def handle_call({:join, %LobbyPlayer{} = player}, _from, %LobbyState{} = state) do
    cond do
      length(state.players) >= @max_players ->
        {:reply, {:error, :full}, state}

      Enum.any?(state.players, fn p -> p.id == player.id end) ->
        {:reply, {:ok, state}, state}

      true ->
        state =
          %LobbyState{state | players: state.players ++ [player]}
          |> notify()

        {:reply, {:ok, state}, state}
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

  defp find_leader(%LobbyState{} = state) do
    # Find first non-ai player ID
    Enum.find(state.players, fn p -> p.is_ai != true end)
  end
end
