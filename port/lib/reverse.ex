defmodule Reverse do
  import DelegateToPortMacro

  delegate_to_port(:reverse, 1)
  delegate_to_port(:faulty_function, 1)
end
