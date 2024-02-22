require 'socket'
require 'digest/md5'
require_relative 'epmd_client'

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
        message_length = node_socket.read(4).unpack1("N")
        incoming_message = node_socket.read(message_length)
        break if incoming_message.nil?

        unless incoming_message.empty?
          puts "Received message:"
          p incoming_message
        end
      end
    end
  end

  def build_send_name_msg
    message_type = "N"
    flags = "0000000000000000000000000000110100000111110111110101111110010101".to_i(2)
    creation = Time.now.to_i
    my_hostname = Socket.gethostname.split(".", 2)[0]
    this_node_full_name = "#{@this_node_name}@#{my_hostname}"

    data = [
      [message_type, nil],
      [flags, "Q>"],
      [creation, "N"],
      [this_node_full_name.size, "n"],
      [this_node_full_name, nil]
    ]

    build_tcp_message(data)
  end

  def receive_status_msg(node_socket)
    message_length = node_socket.read(2).unpack1("n")
    message = node_socket.read(message_length)

    message_type = message.byteslice(0, 1)
    raise "Unexpected message type #{message_type}" unless message_type == "s"

    status = message.byteslice(1, 2)
    raise "Unexpected status: #{status}" unless status == "ok"
  end

  def receive_challenge_msg(node_socket)
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
