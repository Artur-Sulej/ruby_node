defmodule Purple.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Purple.PortGenServer, {:spawn, "ruby lib/reverse.rb"}}
    ]

    opts = [strategy: :one_for_one, name: Purple.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
