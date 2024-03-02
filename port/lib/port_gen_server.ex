defmodule Proxy.PortGenServer do
  @moduledoc """
  GenServer wrapping communication with the port.
  """

  use GenServer

  # Interface

  @doc """
  Starts a GenServer process. port_executable will be passed to Port.open/2.
  """
  def start_link(port_executable) do
    GenServer.start_link(__MODULE__, port_executable)
  end

  @doc """
  Sends a request to the port (kept in the state). It takes MFA, that will be passed to the port.
  Poolboy is used to choose an available worker.
  """
  def send_rpc_to_port(module_name, fun_name, args) when is_list(args) do
    pid = :poolboy.checkout(:port_worker)
    result = GenServer.call(pid, {:send_rpc_to_port, {module_name, fun_name, args}})
    :poolboy.checkin(:port_worker, pid)
    result
  end

  # Internal functions

  # Port is opened and monitored to receive DOWN messages. It's kept in the state.
  def init(port_executable) do
    port = open_port(port_executable)
    {:ok, %{port_executable: port_executable, port: port, callers: %{}}}
  end

  defp open_port(port_executable) do
    port = Port.open(port_executable, [:binary])
    Port.monitor(port)
    port
  end

  # It sends a request to the port and keeps the caller's pid in the state.
  # It allows matching response with the caller using unique message_id.
  # Communication with the port is asynchronous, so :noreply is returned.
  def handle_call({:send_rpc_to_port, {module_name, fun_name, args}}, from_pid, state) do
    message_id = generate_message_id()

    encoded_message =
      Jason.encode!(%{
        headers: %{message_id: message_id},
        payload: Tuple.to_list({module_name, fun_name, args})
      })

    new_state = put_in(state, [:callers, message_id], from_pid)
    Port.command(state.port, "#{encoded_message}\n")

    {:noreply, new_state}
  end

  # Port sends a response. It's decoded and sent back to the caller.
  def handle_info({_port, {:data, encoded_message}}, state) do
    message_ids =
      encoded_message
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(&Jason.decode(&1, keys: :atoms!))
      |> Enum.map(fn
        {:ok,
         %{
           headers: %{message_id: message_id},
           payload: response_payload
         }} ->
          from_pid = Map.fetch!(state.callers, message_id)
          GenServer.reply(from_pid, {:ok, response_payload})
          message_id

        {:ok,
         %{
           headers: %{message_id: message_id},
           error: error
         }} ->
          from_pid = Map.fetch!(state.callers, message_id)
          GenServer.reply(from_pid, {:error, error})
          message_id

        {:error, error} ->
          IO.puts("Error in port: #{inspect(error)}")
          nil
      end)

    callers = Map.drop(state.callers, message_ids)
    {:noreply, %{state | callers: callers}}
  end

  # When port is down, a reply with error is sent to all callers.
  # Then, a new port is opened and kept in the state.
  def handle_info({:DOWN, _ref, :port, _port, reason}, state) do
    state
    |> Map.get(:callers, %{})
    |> Map.values()
    |> Enum.each(&GenServer.reply(&1, {:error, reason}))

    port = open_port(state.port_executable)
    {:noreply, %{port_executable: state.port_executable, port: port, callers: %{}}}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  # Called when the GenServer is terminated. It closes the port.
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
