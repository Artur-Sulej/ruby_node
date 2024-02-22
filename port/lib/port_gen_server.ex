defmodule Purple.PortGenServer do
  use GenServer

  def start_link(port_executable) do
    GenServer.start_link(__MODULE__, port_executable)
  end

  def init(port_executable) do
    port = Port.open(port_executable, [:binary])
    Port.monitor(port)
    {:ok, %{port: port, callers: %{}}}
  end

  def send_payload([module_name, fun_name, args]) when is_list(args) do
    pid = :poolboy.checkout(:port_worker)
    result = GenServer.call(pid, {:send_payload, [module_name, fun_name, args]})
    :poolboy.checkin(:port_worker, pid)
    result
  end

  def handle_call({:send_payload, request_payload}, from_pid, state) do
    message_id = generate_message_id()

    encoded_message =
      Jason.encode!(%{
        headers: %{message_id: message_id},
        payload: request_payload
      })

    new_state = put_in(state, [:callers, message_id], from_pid)
    Port.command(state.port, "#{encoded_message}\n")

    {:noreply, new_state}
  end

  def handle_info({_port, {:data, encoded_message}}, state) do
    decoded_messages =
      encoded_message
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(&Jason.decode!(&1, keys: :atoms!))

    message_ids =
      Enum.map(
        decoded_messages,
        fn %{
             headers: %{message_id: message_id},
             payload: response_payload
           } ->
          from_pid = Map.fetch!(state.callers, message_id)
          GenServer.reply(from_pid, {:ok, response_payload})
          message_id
        end
      )

    callers = Map.drop(state.callers, message_ids)
    {:noreply, %{state | callers: callers}}
  end

  def handle_info({:DOWN, _ref, :port, _port, reason}, state) do
    state
    |> Map.get(:callers, %{})
    |> Map.values()
    |> Enum.each(&GenServer.reply(&1, {:error, reason}))

    GenServer.stop(self(), :restart_needed)
    {:noreply, %{}}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    port = state[:port]

    cond do
      is_nil(port) -> :ok
      port |> Port.info() |> is_nil() -> :ok
      true -> Port.close(port)
    end

    :ok
  end

  defp generate_message_id() do
    make_ref() |> :erlang.term_to_binary() |> Base.encode64()
  end
end
