require 'socket'
require 'digest/md5'

NODE_SHORT_NAME = "red_node"

def send_name
  message_type = "N"
  flags = "0000000000000000000000000000110100000111110111110101111110010101".to_i(2)
  creation = Time.now.to_i
  my_hostname = Socket.gethostname.split(".", 2)[0]
  this_node_name = "#{NODE_SHORT_NAME}@#{my_hostname}"

  data = [
    [message_type, nil],
    [flags, "Q>"],
    [creation, "N"],
    [this_node_name.size, "n"],
    [this_node_name, nil]
  ]

  build_tcp_message(data)
end

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

def build_challenge_reply(their_challenge)
  message_type = "r"
  my_challenge = rand(0xffffffff)
  digest = Digest::MD5.digest(get_cookie.to_s + their_challenge.to_s)

  data = [
    [message_type, nil],
    [my_challenge, "N"],
    [digest, nil],
  ]

  build_tcp_message(data)
end

def get_cookie
  File.read("/Users/#{ENV['USER']}/.erlang.cookie")
end

socket = TCPSocket.open("localhost", 60071)
socket.write send_name

message_length = socket.read(2).unpack1("n")
message = socket.read(message_length)

message_type = message.byteslice(0, 1)
raise "Unexpected message type" unless message_type == "s"
status = message.byteslice(1, 2)
raise "Unexpected status: #{status}" unless status == "ok"

message_length = socket.read(2).unpack1("n")
message = socket.read(message_length)

message_type = message.byteslice(0, 1)
flags = message.byteslice(1, 8).unpack1("Q>").to_s(2)
challenge = message.byteslice(9, 4).unpack1("N")
creation = message.byteslice(13, 4).unpack1("N")
name_size = message.byteslice(17, 2).unpack1("n")
their_name = message.byteslice(19, name_size)
socket.write build_challenge_reply(challenge)

p "_______________"
p message_type
p flags
p challenge
p creation
p name_size
p their_name
p "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯"

message_length = socket.read(2).unpack1("n")
message = socket.read(message_length)

message_type = message.byteslice(0, 1)
their_digest = message.byteslice(1, 8).unpack1("Q>")

p "_______________"
p message_type
p their_digest
p "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯"

# KEEP_ALIVE

loop do
  socket.write [0].pack("N")
  sleep 15
end

sleep 3000000

