defmodule Proxy.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Starting poolboy that will manage PortGenServers.
    # It's a generic, framework-like solution, so it can be used with other processes, languages etc.
    # In this case args to start Ruby app are passed.

    children = [
      :poolboy.child_spec(:port_worker, poolboy_config(), {:spawn, "ruby lib/reverse.rb"})
    ]

    opts = [strategy: :one_for_one, name: Proxy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp poolboy_config do
    [
      name: {:local, :port_worker},
      worker_module: Proxy.PortGenServer,
      size: 10,
      max_overflow: 0,
      strategy: :fifo
    ]
  end
end
