$stdout.sync = true

while input = gets
  puts "Greetings from Ruby: #{input.strip.reverse}"
end
