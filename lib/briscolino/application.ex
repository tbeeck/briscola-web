defmodule Briscolino.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DNSCluster, query: Application.get_env(:briscolino, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Briscolino.PubSub},
      Briscolino.Presence,
      Briscolino.GameSupervisor,
      {Horde.Registry, keys: :unique, name: Briscolino.GameRegistry},
      Briscolino.LobbySupervisor,
      {Horde.Registry, keys: :unique, name: Briscolino.LobbyRegistry},
      BriscolinoWeb.Telemetry,
      # Start to serve requests, typically the last entry
      BriscolinoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Briscolino.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BriscolinoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
