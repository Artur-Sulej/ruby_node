defmodule Reverse do
  def reverse(arg) do
    Purple.PortGenServer.send_payload(["Reverse", "reverse", [arg]])
  end
end
