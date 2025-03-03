defmodule BriscolinoWeb.LiveGame.LobbyComponents do
  use Phoenix.Component
  use Gettext, backend: BriscolinoWeb.Gettext

  import BriscolinoWeb.CoreComponents

  alias Briscolino.LobbyServer
  alias Briscolino.LobbyServer.LobbyState

  @doc """
  Renders players in the sidebar, either for
  a game or a lobby.
  """
  attr :lobby, LobbyState, required: true
  attr :highlighted, :integer, default: nil

  def lobby_player_list(assigns) do
    ~H"""
    <ul class="pl-4 text-primary_text">
      <%= for {player, idx} <- Enum.with_index(@lobby.players) do %>
        <li class="rounded-md" ]}>
          <div class="flex flex-row items-center p-2">
            <div class="rounded-full w-12 h-12 m-2 mr-4 outline
                        flex items-center justify-center">
              Image
            </div>
            <div class="flex flex-col flex-grow">
              <.player_name name={player.name} highlighted={@highlighted == idx} />
              <div class="flex flex-row items-center">
                <span class="pl-4 text-md flex items-center">
                  [ 0 ]
                </span>
              </div>
            </div>
          </div>
        </li>
      <% end %>
      <%= if !LobbyServer.lobby_full(@lobby) do %>
        <%= for _ <- 0..(4-length(@lobby.players)-1) do %>
          <div class="flex flex-row items-center p-2">
            <div class="rounded-full w-12 h-12 m-2 mr-4 outline flex items-center justify-center">
              <.icon name="hero-plus" class="w-[50%] h-[50%]" />
            </div>
            <div class="flex flex-col flex-grow">
              <div class="text-lg">...</div>
              <div class="flex flex-row items-center">
                <span class="pl-4 text-md flex items-center">
                  [ 0 ]
                </span>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </ul>
    """
  end
end
