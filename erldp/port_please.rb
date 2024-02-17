require 'socket'

EPMD_PORT = 4369
THEIR_NODE_SHORT_NAME = "purple_node"

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

epmd_socket = TCPSocket.new("127.0.0.1", EPMD_PORT)

data = [
  [122, "C"],
  [THEIR_NODE_SHORT_NAME, nil]
]

epmd_socket.write build_tcp_message(data)
message = epmd_socket.read

message_type = message.byteslice(0, 1).unpack1("C")
result = message.byteslice(1, 1).unpack1("C")
port = message.byteslice(2, 2).unpack1("n")

p "_______________"
p [message_type, result, port]
p "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯"
