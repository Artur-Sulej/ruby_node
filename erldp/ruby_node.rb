require 'socket'
require 'digest/md5'
require_relative 'epmd_client'
require_relative 'rpc_serializer'
require_relative 'reverse'

class RubyNode
  HOST = "localhost"

  def initialize(this_node_name, their_node_name, cookie = nil)
    @this_node_name = this_node_name
    @their_node_name = their_node_name
    @cookie = cookie || get_file_cookie
  end

  def connect_node
    their_port = fetch_port
    node_socket = perform_handshake(their_port)
    keep_alive(node_socket)
    listen_for_messages(node_socket)
  end

  private

  def fetch_port
    epmd_client.port_please(@their_node_name)
  end

  def epmd_client
    @epmd_client ||= EPMDClient.new
  end

  def perform_handshake(their_port)
    node_socket = TCPSocket.open(HOST, their_port)
    node_socket.write build_send_name_msg
    receive_status_msg(node_socket)
    challenge = receive_challenge_msg(node_socket)
    node_socket.write build_challenge_reply_msg(challenge)
    receive_challenge_ack_msg(node_socket)

    node_socket
  end

  def keep_alive(node_socket)
    Thread.new do
      loop do
        node_socket.write [0].pack("N")
        sleep 15
      end
    end
  end

  def listen_for_messages(node_socket)
    puts "Reading from socket..."

    Thread.new do
      loop do
        raise "Socket closed" if node_socket.closed?
        message_length = node_socket.read(4)&.unpack1("N")
        incoming_message = node_socket.read(message_length)
        break if incoming_message.nil?

        unless incoming_message.empty?
          decoded_message = RPCSerializer.binary_to_term(incoming_message)
          next unless decoded_message

          module_name, function_name, arguments = decoded_message
          apply_function(module_name, function_name, arguments)
        end
      end
    end
  end

  def apply_function(module_name, function_name, arguments)
    begin
      mod = Object.const_get(module_name)
      result = mod.public_send(function_name, *arguments)
      puts "Result: #{result}"
      result
    rescue => e
      puts "Error: #{e}"
      nil
    end
  end

  def build_send_name_msg
    message_type = "N"
    flags = "0000000000000000000000000000110100000111110111110101111110010101".to_i(2)
    creation = Time.now.to_i
    my_hostname = Socket.gethostname.split(".", 2)[0]
    this_node_full_name = "#{@this_node_name}@#{my_hostname}"

    # Each part of message is prepared and packed into
    # appropriate byte representation.
    # All numbers are big-endian (order of bytes).
    data = [
      [message_type, nil],             # string
      [flags, "Q>"],                   # 8-byte big-endian
      [creation, "N"],                 # 4-byte big-endian
      [this_node_full_name.size, "n"], # 2-byte big-endian
      [this_node_full_name, nil]       # string
    ]

    build_tcp_message(data)
  end

  def receive_status_msg(node_socket)
    # Read 2-bytes (big-endian) and interpret them as a number
    message_length = node_socket.read(2).unpack1("n")
    # Use this number to read this number of bytes
    message = node_socket.read(message_length)

    # Get 1 byte from the message
    message_type = message.byteslice(0, 1)
    raise "Unexpected message type #{message_type}" unless message_type == "s"

    # Get next 2 bytes from the message
    status = message.byteslice(1, 2)
    raise "Unexpected status: #{status}" unless status == "ok"
  end

  def receive_challenge_msg(node_socket)
    # Similar pattern: read size, read the rest, interpret the content
    message_length = node_socket.read(2).unpack1("n")
    message = node_socket.read(message_length)
    _message_type = message.byteslice(0, 1)
    _flags = message.byteslice(1, 8).unpack1("Q>").to_s(2)
    challenge = message.byteslice(9, 4).unpack1("N")
    _creation = message.byteslice(13, 4).unpack1("N")
    name_size = message.byteslice(17, 2).unpack1("n")
    _their_name = message.byteslice(19, name_size)
    challenge
  end

  def build_challenge_reply_msg(their_challenge)
    message_type = "r"
    my_challenge = rand(0xffffffff)
    digest = Digest::MD5.digest(@cookie + their_challenge.to_s)

    data = [
      [message_type, nil],
      [my_challenge, "N"],
      [digest, nil],
    ]

    build_tcp_message(data)
  end

  def receive_challenge_ack_msg(node_socket)
    message_length = node_socket.read(2).unpack1("n")
    message = node_socket.read(message_length)

    message_type = message.byteslice(0, 1)
    their_digest = message.byteslice(1, 8).unpack1("Q>")

    raise "Unexpected message type #{message_type}" unless message_type == "a"
    raise "Invalid digest received #{their_digest}" unless validate_digest(their_digest)
  end

  # [1709847958].pack("N")
  # => "e\xEA5\x96"
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

  def get_file_cookie
    File.read("/Users/#{ENV['USER']}/.erlang.cookie")
  end

  def validate_digest(_their_digest)
    true
  end
end
