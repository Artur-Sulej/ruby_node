require "json"

$stdout.sync = true

module Reverse
  def self.reverse(string)
    string.reverse
  end
end

while input = gets
  request = JSON.parse!(input.strip)
  headers = request["headers"]
  module_name, function_name, arguments = request["payload"]

  mod = Object.const_get(module_name)
  result = mod.public_send(function_name, *arguments)

  response = {
    "headers" => headers,
    "payload" => result
  }

  puts response.to_json
end
