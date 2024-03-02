defmodule Reverse do
  import DelegateToPortMacro

  delegate_to_port(:reverse, 1)

  #  def reverse(arg) do
  #    Proxy.PortGenServer.send_payload(["Reverse", "reverse", [arg]])
  #  end
end
