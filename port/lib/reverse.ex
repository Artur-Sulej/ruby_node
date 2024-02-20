defmodule Reverse do
  import DelegateToPortMacro

  delegate_to_port(:reverse, 1)
end
