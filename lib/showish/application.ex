defmodule Showish.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ShowishWeb.Telemetry,
      Showish.Repo,
      {DNSCluster, query: Application.get_env(:showish, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Showish.PubSub},
      # Start a worker by calling: Showish.Worker.start_link(arg)
      # {Showish.Worker, arg},
      # Start to serve requests, typically the last entry
      ShowishWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Showish.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ShowishWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
