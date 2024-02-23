require_relative 'erlang'

module RPCSerializer
  def self.binary_to_term(string)
    string = string.force_encoding("ASCII-8BIT")
    message_part = string.split("jl", 2)[1]
    return unless message_part
    prepared_input = message_part.prepend("\x83l".force_encoding("ASCII-8BIT"))
    parsed_data = Erlang.binary_to_term(prepared_input)

    module_name = parsed_data.value[1].to_s.delete_prefix("Elixir.")
    function_name = parsed_data.value[2]
    arguments = parsed_data.value[3].value
    arguments = transform_array(arguments)

    [module_name, function_name, arguments]
  end

  private

  def self.transform_array(data)
    data.map(&method(:transform_item))
  end

  def self.transform_hash(data)
    data
      .transform_values(&method(:transform_item))
      .transform_keys(&method(:transform_item))
  end

  def self.transform_item(item)
    item = item.respond_to?(:value) ? item.value : item

    if item.is_a?(Array)
      transform_array(item)
    elsif item.is_a?(Hash)
      transform_hash(item)
    else
      item
    end
  end
end
