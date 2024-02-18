require "json"

$stdout.sync = true

while input = gets
  request = JSON.parse!(input.strip)
  headers = request["headers"]
  payload = request["payload"]

  response = {
    "headers" => headers,
    "payload" => payload.reverse
  }

  puts response.to_json
end
