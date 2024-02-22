require 'socket'

class EPMDClient
  EPMD_PORT = 4369
  HOST = "127.0.0.1"

  def initialize
    @socket = TCPSocket.new(HOST, EPMD_PORT)
  end

  def port_please(node_name)
    data = [
      [122, "C"],
      [node_name, nil]
    ]

    @socket.write build_tcp_message(data)
    message = @socket.read
    message_type = message.byteslice(0, 1)
    raise "Unexpected EPMD message type #{message_type}" unless message_type == "w"
    status = message.byteslice(1, 1).unpack1("C")
    raise "Unexpected EPMD status: #{status}" unless status == 0
    port = message.byteslice(2, 2).unpack1("n")
    port
  end

  private

  def build_tcp_message(data)
    encoded_data =
      data.map do |(value, pack)|
        if pack
          [value].pack(pack)
        else
          value
        end
      end.join

    [encoded_data.size].pack("n") + encoded_data
  end
end
