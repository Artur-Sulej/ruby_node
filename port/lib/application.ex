defmodule Purple.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      :poolboy.child_spec(:port_worker, poolboy_config(), {:spawn, "ruby lib/reverse.rb"})
    ]

    opts = [strategy: :one_for_one, name: Purple.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp poolboy_config do
    [
      name: {:local, :port_worker},
      worker_module: Purple.PortGenServer,
      size: 10,
      max_overflow: 0,
      strategy: :fifo
    ]
  end
end
