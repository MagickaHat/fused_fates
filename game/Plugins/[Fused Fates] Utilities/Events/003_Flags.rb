#================================================================================================
# Pokémon Fused Fates Utilities/Events - 003_Flags.rb
#================================================================================================

#==================================================================
# class EventFlagData
#==================================================================
# @brief Named story flags kept in the save file ($event_flags).
# A flag can hold any value that can be saved (true/false, a number, a symbol, a string...).
# Flags that have never been set read as nil.
class EventFlagData
  def initialize
    @flags = {}   # Symbol => value
  end

  # @param name [Symbol, String]
  # @return [Object, nil]
  def [](name)
    return @flags[name.to_sym]
  end

  # @param name [Symbol, String]
  # @param value [Object] nil removes the flag.
  def []=(name, value)
    if value.nil?
      @flags.delete(name.to_sym)
    else
      @flags[name.to_sym] = value
    end
  end

  # @param name [Symbol, String]
  # @return [Boolean] Whether the flag has been set (to anything).
  def key?(name)
    return @flags.key?(name.to_sym)
  end

  # @param name [Symbol, String]
  def delete(name)
    @flags.delete(name.to_sym)
  end

  # @brief Removes every flag.
  def clear
    @flags.clear
  end

  # @return [Hash{Symbol => Object}] A copy of every flag.
  def to_h
    return @flags.clone
  end

  SaveData.register(:event_flags) do
    ensure_class :EventFlagData
    save_value { $event_flags }
    load_value { |value| $event_flags = value }
    new_game_value { EventFlagData.new }
  end
end

#==================================================================
# module EventUtils (flags)
#==================================================================
module EventUtils
  module_function

  # @brief The flag store, created if no save has been loaded yet.
  # @return [EventFlagData]
  def flags
    $event_flags ||= EventFlagData.new
    return $event_flags
  end

  # @brief Reads a flag.
  # @param name [Symbol, String]
  # @param default [Object] Returned if the flag isn't set.
  # @return [Object]
  def flag(name, default = nil)
    return flags.key?(name) ? flags[name] : default
  end

  # @brief Checks whether a flag is set to a truthy value (not nil, false or 0).
  # @param name [Symbol, String]
  # @return [Boolean]
  def flag?(name)
    value = flags[name]
    return !!value && value != 0
  end

  # @brief Sets a flag.
  # @param name [Symbol, String]
  # @param value [Object] nil clears it.
  # @return [Object] The value.
  def set_flag(name, value = true)
    flags[name] = value
    return value
  end

  # @brief Removes a flag.
  # @param name [Symbol, String]
  def clear_flag(name)
    flags.delete(name)
  end

  # @brief Flips a flag between true and false.
  # @param name [Symbol, String]
  # @return [Boolean] The new value.
  def toggle_flag(name)
    return set_flag(name, !flag?(name))
  end

  # @brief Adds to a counter flag (an unset flag counts as 0).
  # @param name [Symbol, String]
  # @param by [Numeric]
  # @return [Numeric] The new value.
  def increment_flag(name, by = 1)
    return set_flag(name, flag(name, 0).to_i + by)
  end

  # @brief Prints every flag to the console. Does nothing outside debug mode.
  def dump_flags
    return if !$DEBUG
    all = flags.to_h
    Console.echo_h2("Event flags (#{all.length})", text: :white)
    all.sort_by { |key, _value| key.to_s }.each do |key, value|
      Console.echoln("#{key} = #{value.inspect}")
    end
  end
end
