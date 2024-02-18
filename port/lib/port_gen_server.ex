defmodule Purple.PortGenServer do
  use GenServer

  def start_link(port_executable) do
    GenServer.start_link(__MODULE__, port_executable, name: __MODULE__)
  end

  def init(port_executable) do
    port = Port.open(port_executable, [:binary])
    Port.monitor(port)
    {:ok, %{port: port, callers: %{}}}
  end

  def send_payload(payload) do
    GenServer.call(__MODULE__, {:send_payload, payload})
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
    %{
      headers: %{message_id: message_id},
      payload: response_payload
    } = Jason.decode!(encoded_message, keys: :atoms!)

    from_pid = Map.fetch!(state.callers, message_id)
    GenServer.reply(from_pid, {:ok, response_payload})
    {:noreply, %{state | callers: Map.delete(state.callers, message_id)}}
  end

  def handle_info({:DOWN, _ref, :port, _port, _reason}, state) do
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp generate_message_id() do
    make_ref() |> :erlang.term_to_binary() |> Base.encode16()
  end
end
