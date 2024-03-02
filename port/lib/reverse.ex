defmodule Reverse do
  @moduledoc """
  This a gateway module required for :rpc.call to work. MFA used in :rpc.call must be implemented
  in Elixir. It delegates the calls to PortGenServer, which then sends them to the port.
  """

  def reverse(arg) do
    Proxy.PortGenServer.send_rpc_to_port("Reverse", "reverse", [arg])
  end

  # Fancy macro for syntactic sugar
  # import DelegateToPortMacro
  # delegate_to_port(:reverse, 1)
end
