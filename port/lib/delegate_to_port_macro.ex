defmodule DelegateToPortMacro do
  defmacro delegate_to_port(function_name, arity) do
    arguments = Enum.map(1..arity, &Macro.var(:"arg#{&1}", nil))

    quote do
      def unquote(function_name)(unquote_splicing(arguments)) do
        Purple.PortGenServer.send_payload([
          __MODULE__ |> inspect() |> String.replace(".", "::"),
          Atom.to_string(unquote(function_name)),
          [unquote_splicing(arguments)]
        ])
      end
    end
  end
end