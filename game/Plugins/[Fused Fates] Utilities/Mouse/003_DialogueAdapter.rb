#================================================================================================
# Pokémon Fused Fates Utilities/Mouse - 003_DialogueAdapter.rb
#================================================================================================

#==================================================================
# class DialogueAdapter
#==================================================================
# @brief Lets a left click anywhere in the game window advance dialogue, as Input::USE does.
class DialogueAdapter < UIAdapter
  # @brief A left click counts as Input::USE.
  # @param button [Integer]
  # @return [Boolean]
  def trigger?(button)
    return button == Input::USE && MouseInput.clicked?
  end
end

#==================================================================
# module DialogueMouse
#==================================================================
# @brief Wraps dialogue code in a DialogueAdapter when mouse dialogue is enabled.
module DialogueMouse
  module_function

  # @brief Runs a block with mouse dialogue active.
  # @return [Object] The block's result.
  def with_dialogue(&block)
    return yield if !UtilitySettings::MOUSE_DIALOGUE
    return MouseUI.with(DialogueAdapter.new, &block)
  end

  # @brief Runs a block where clicks don't count as button presses (choices, number entry),
  # so a click can't pick whichever option happens to be highlighted.
  # @return [Object] The block's result.
  def without_mouse(&block)
    return MouseUI.with(BlockingAdapter.new, &block)
  end
end

#==================================================================
# Overworld messages
#==================================================================
alias __mouse_pbMessageDisplay pbMessageDisplay unless defined?(__mouse_pbMessageDisplay)
alias __mouse_pbMessageWaitForInput pbMessageWaitForInput unless defined?(__mouse_pbMessageWaitForInput)
alias __mouse_pbShowCommands pbShowCommands unless defined?(__mouse_pbShowCommands)
alias __mouse_pbShowCommandsWithHelp pbShowCommandsWithHelp unless defined?(__mouse_pbShowCommandsWithHelp)
alias __mouse_pbChooseNumber pbChooseNumber unless defined?(__mouse_pbChooseNumber)

# @brief Displays a message; a left click advances it.
def pbMessageDisplay(*args, &block)
  return DialogueMouse.with_dialogue { __mouse_pbMessageDisplay(*args, &block) }
end

# @brief Waits for input after a message; a left click ends the wait.
def pbMessageWaitForInput(*args, &block)
  return DialogueMouse.with_dialogue { __mouse_pbMessageWaitForInput(*args, &block) }
end

# @brief Shows a choice list; clicks are ignored until choices get their own adapter.
def pbShowCommands(*args, &block)
  return DialogueMouse.without_mouse { __mouse_pbShowCommands(*args, &block) }
end

# @brief Shows a choice list with help text; clicks are ignored.
def pbShowCommandsWithHelp(*args, &block)
  return DialogueMouse.without_mouse { __mouse_pbShowCommandsWithHelp(*args, &block) }
end

# @brief Asks for a number; clicks are ignored.
def pbChooseNumber(*args, &block)
  return DialogueMouse.without_mouse { __mouse_pbChooseNumber(*args, &block) }
end

#==================================================================
# Battle messages
#==================================================================
class Battle::Scene
  alias __mouse_pbDisplayMessage pbDisplayMessage unless method_defined?(:__mouse_pbDisplayMessage)
  alias __mouse_pbDisplayPausedMessage pbDisplayPausedMessage unless method_defined?(:__mouse_pbDisplayPausedMessage)

  # @brief Displays a battle message; a left click advances it.
  def pbDisplayMessage(*args, &block)
    return DialogueMouse.with_dialogue { __mouse_pbDisplayMessage(*args, &block) }
  end

  # @brief Displays a battle message that waits for input; a left click advances it.
  def pbDisplayPausedMessage(*args, &block)
    return DialogueMouse.with_dialogue { __mouse_pbDisplayPausedMessage(*args, &block) }
  end
end
