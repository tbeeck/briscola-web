defmodule Briscolino.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BriscolinoWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:briscolino, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Briscolino.PubSub},
      Briscolino.GameSupervisor,
      # Start the Finch HTTP client for sending emails
      {Finch, name: Briscolino.Finch},
      # Start a worker by calling: Briscolino.Worker.start_link(arg)
      # {Briscolino.Worker, arg},
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
