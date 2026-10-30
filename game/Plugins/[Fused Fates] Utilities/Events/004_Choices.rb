#================================================================================================
# Pokémon Fused Fates Utilities/Events - 004_Choices.rb
#================================================================================================

#==================================================================
# module EventUtils (choices)
#==================================================================
module EventUtils
  module_function

  # @brief Shows a message with a choice menu and returns the chosen option's symbol.
  #
  #   case EventUtils.choose(_INTL("Which way?"), { left: _INTL("Left"), right: _INTL("Right") }, cancel: :right)
  #   when :left  then ...
  #   when :right then ...
  #   end
  #
  # @param message [String]
  # @param choices [Hash{Symbol => String}, Array<Symbol>] Options in display order. With an Array,
  #   each symbol is shown capitalized (:go_back becomes "Go back").
  # @param cancel [Symbol, nil] Returned when the player cancels; nil means they can't cancel.
  #   It doesn't have to be one of the options.
  # @param default [Symbol, nil] Option the cursor starts on; nil for the first one.
  # @return [Symbol]
  def choose(message, choices, cancel: nil, default: nil)
    choices = choices.to_h { |sym| [sym, sym.to_s.tr("_", " ").capitalize] } if choices.is_a?(Array)
    keys = choices.keys
    cancel_index = keys.index(cancel)
    cmd_if_cancel = if cancel.nil?         then 0
                    elsif cancel_index     then cancel_index + 1
                    else                        -1   # Cancel returns a symbol that isn't listed
                    end
    default_index = keys.index(default) || 0
    index = pbMessage(message, choices.values, cmd_if_cancel, nil, default_index)
    return (index < 0) ? cancel : keys[index]
  end
end
