#================================================================================================
# Pokémon Fused Fates Utilities/Mouse - 003_DialogueAdapter.rb
#================================================================================================

#==================================================================
# class DialogueAdapter
#==================================================================
# @brief Lets a left click anywhere in the game window advance dialogue, as Input::USE does.
# A right click acts as Input::BACK, which also advances message boxes.
class DialogueAdapter < UIAdapter
  # @brief A left click counts as Input::USE; other buttons fall back to UIAdapter.
  # @param button [Integer]
  # @return [Boolean]
  def trigger?(button)
    return true if button == Input::USE && MouseInput.clicked?
    return super
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

  # @brief Runs a block where only a right click (Back) is mapped, e.g. number entry, so a
  # left click can't confirm whatever number happens to be shown.
  # @return [Object] The block's result.
  def back_only(&block)
    return MouseUI.with(UIAdapter.new, &block)
  end
end

#==================================================================
# Overworld messages
#==================================================================
alias __mouse_pbMessageDisplay pbMessageDisplay unless defined?(__mouse_pbMessageDisplay)
alias __mouse_pbMessageWaitForInput pbMessageWaitForInput unless defined?(__mouse_pbMessageWaitForInput)
alias __mouse_pbChooseNumber pbChooseNumber unless defined?(__mouse_pbChooseNumber)

# @brief Displays a message; a left click advances it.
def pbMessageDisplay(*args, &block)
  return DialogueMouse.with_dialogue { __mouse_pbMessageDisplay(*args, &block) }
end

# @brief Waits for input after a message; a left click ends the wait.
def pbMessageWaitForInput(*args, &block)
  return DialogueMouse.with_dialogue { __mouse_pbMessageWaitForInput(*args, &block) }
end

# @brief Asks for a number; a right click cancels and left clicks are ignored.
def pbChooseNumber(*args, &block)
  return DialogueMouse.back_only { __mouse_pbChooseNumber(*args, &block) }
end

# Plugin code is evaluated at the top level, which makes these redefinitions private. Essentials
# calls some of them with an explicit receiver (e.g. Kernel.pbShowCommands), so keep them public
# like the originals.
Object.send(:public, :pbMessageDisplay, :pbMessageWaitForInput, :pbChooseNumber)

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
