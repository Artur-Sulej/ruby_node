port = Port.open({:spawn, "ruby reverse.rb"}, [:binary])

Port.command(port, "No palindromes here!\n")

result =
  receive do
    {^port, {:data, data}} -> data
  after
    2000 -> {:error, "Timeout! No data received from Ruby!"}
  end

IO.puts("Result: #{inspect(result)}")

Port.close(port)

# Run:
# elixir reverse.ex
