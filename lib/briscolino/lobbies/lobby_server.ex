defmodule Briscolino.LobbyServer do
  use GenServer

  alias Briscolino.GameServer
  alias Briscolino.GameSupervisor
  alias Phoenix.PubSub

  @max_players 4
  @cleanup_timeout Application.compile_env(:briscolino, [:genserver_settings, :cleanup_timeout])

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

  def remove_ai(pid, player_id) do
    GenServer.call(pid, {:remove_ai, player_id})
  end

  def start_game(pid, player_id) do
    GenServer.call(pid, {:start_game, player_id})
  end

  @impl true
  def init(%LobbyState{} = arg) do
    PubSub.subscribe(Briscolino.PubSub, lobby_presence_topic(arg.id))
    {:ok, arg, @cleanup_timeout}
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

    {:noreply, new_state} |> with_timeout()
  end

  @impl true
  def handle_info(:timeout, %LobbyState{} = state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_call(:state, _from, %LobbyState{} = state) do
    {:reply, {:ok, state}, state} |> with_timeout()
  end

  @impl true
  def handle_call({:join, %LobbyPlayer{} = player, initiator_id}, from, %LobbyState{} = state) do
    if is_leader(state, initiator_id) do
      handle_call({:join, player}, from, state)
    else
      {:reply, {:error, :not_leader}, state} |> with_timeout()
    end
  end

  @impl true
  def handle_call({:join, %LobbyPlayer{} = player}, _from, %LobbyState{} = state) do
    cond do
      lobby_full(state) ->
        {:reply, {:error, :full}, state}

      Enum.any?(state.players, fn p -> p.id == player.id end) ->
        {:reply, {:ok, state}, state}

      true ->
        state =
          %LobbyState{state | players: state.players ++ [player]}
          |> notify()

        {:reply, {:ok, state}, state}
    end
    |> with_timeout()
  end

  @impl true
  def handle_call({:leave, player_id}, _from, %LobbyState{players: players} = state) do
    new_players = Enum.reject(players, fn p -> p.id == player_id end)

    state =
      %LobbyState{state | players: new_players}
      |> notify()

    {:reply, {:ok, state}, state}
    |> with_timeout()
  end

  @impl true
  def handle_call({:remove_ai, initiator_id}, from, %LobbyState{} = state) do
    ai_player = find_ai(state)

    cond do
      ai_player == nil ->
        {:reply, {:error, :no_ai}, state} |> with_timeout()

      !is_leader(state, initiator_id) ->
        {:reply, {:error, :not_leader}, state} |> with_timeout()

      true ->
        handle_call({:leave, ai_player.id}, from, state)
    end
  end

  @impl true
  def handle_call({:start_game, initiator_id}, _from, %LobbyState{} = state) do
    cond do
      not lobby_full(state) ->
        {:reply, {:error, :not_enough_players}, state} |> with_timeout()

      not is_leader(state, initiator_id) ->
        {:reply, {:error, :not_leader}, state} |> with_timeout()

      true ->
        {:reply, make_game(state), state}
    end
  end

  defp make_game(%LobbyState{} = state) do
    players = to_game_players(state)

    case GameSupervisor.new_game(players) do
      {:ok, pid} ->
        # Get game ID and notify players that the game started
        notify_game_start(state, pid)
        {:ok, pid}

      {:error, _err} ->
        {:error, :create_game_failed}
    end
  end

  defp to_game_players(%LobbyState{} = lobby) do
    Enum.map(lobby.players, fn p ->
      %GameServer.PlayerInfo{
        name: p.name,
        play_token: p.id,
        ai_strategy:
          case p.is_ai do
            true -> Briscola.Strategy.Random
            _ -> nil
          end
      }
    end)
  end

  defp notify(state) do
    Phoenix.PubSub.broadcast(Briscolino.PubSub, lobby_topic(state.id), {:lobby, state})
    state
  end

  defp notify_game_start(lobby_state, game_pid) do
    {:ok, game_state} = GameServer.state(game_pid)

    Phoenix.PubSub.broadcast(
      Briscolino.PubSub,
      lobby_topic(lobby_state.id),
      {:game_start, game_state.id}
    )

    lobby_state
  end

  defp is_leader(state, player_id) do
    case find_leader(state) do
      nil -> false
      leader -> leader.id == player_id
    end
  end

  defp find_leader(%LobbyState{} = state) do
    # Find first non-ai player ID
    Enum.find(state.players, fn p -> p.is_ai != true end)
  end

  defp find_ai(%LobbyState{} = state) do
    Enum.find(state.players, fn p -> p.is_ai end)
  end

  defp lobby_full(%LobbyState{} = state) do
    length(state.players) == @max_players
  end

  defp with_timeout({:reply, reply, state}), do: {:reply, reply, state, @cleanup_timeout}
  defp with_timeout({:noreply, state}), do: {:noreply, state, @cleanup_timeout}
end
