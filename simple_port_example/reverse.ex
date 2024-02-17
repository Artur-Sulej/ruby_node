defmodule ReversePort do
  def start do
    Port.open({:spawn, "ruby reverse.rb"}, [:binary])
  end

  def send_data(port, data) do
    Port.command(port, "#{data}\n")
  end

  def receive_data(port) do
    receive do
      {^port, {:data, data}} -> data
    after
      2000 -> {:error, :timeout}
    end
  end
end

{:ok, port} = ReversePort.start()
ReversePort.send_data(port, "No palindromes here!")
result = ReversePort.receive_data(port)
IO.puts("Result: #{inspect(result)}")

# Run:
# elixir reverse.ex
