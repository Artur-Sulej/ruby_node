require "json"

$stdout.sync = true
$stderr = $stdout

module Reverse
  def self.reverse(string)
    string.reverse
  end
end

while input = gets
  begin
    request = JSON.parse!(input.strip)
    headers = request["headers"]
    module_name, function_name, arguments = request["payload"]

    # Getting MFA and invoking given module
    mod = Object.const_get(module_name)
    result = mod.public_send(function_name, *arguments)

    response = {
      "headers" => headers,
      "payload" => result
    }

    puts response.to_json

  rescue => e
    response = {
      "headers" => headers,
      "error" => e.message
    }

    puts response.to_json
  end
end
