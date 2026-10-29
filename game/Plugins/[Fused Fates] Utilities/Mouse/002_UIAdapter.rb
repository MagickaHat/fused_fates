#================================================================================================
# Pokémon Fused Fates Utilities/Mouse - 002_UIAdapter.rb
#================================================================================================
# Mouse support works through UI adapters. An adapter turns what the mouse did this frame
# into the buttons a screen already listens for (Input::USE, Input::BACK, ...), so existing
# Essentials loops gain mouse support without being rewritten.
#
# Adapters live on a stack (MouseUI); only the top one is asked. While it is active,
# Input.trigger?(button) is also true whenever the adapter says the mouse produced that button.
#
# Adding mouse support to a new screen:
#   1. Subclass UIAdapter and override #trigger? (and #update if it needs per-frame state).
#   2. Run the screen's main loop inside MouseUI.with(MyAdapter.new) { ... }, usually by
#      aliasing the method that runs it (see 003_DialogueAdapter.rb).
#   3. Wrap anything inside it that must ignore the outer adapter in a BlockingAdapter.

#==================================================================
# class UIAdapter
#==================================================================
# @brief Base class for objects that translate mouse input into button presses.
class UIAdapter
  # @brief Checks whether the mouse pressed a button this frame.
  # @param button [Integer] An Input button constant such as Input::USE.
  # @return [Boolean]
  def trigger?(button)
    return false
  end

  # @brief Called once per frame by Input.update while the adapter is on top of the stack.
  def update; end

  # @brief Called when the adapter is pushed onto the stack.
  def on_push; end

  # @brief Called when the adapter is popped off the stack.
  def on_pop; end
end

#==================================================================
# class BlockingAdapter
#==================================================================
# @brief An adapter that maps nothing. Push it over screens that don't support the mouse yet
# so an outer adapter (e.g. dialogue) can't turn clicks into presses there.
class BlockingAdapter < UIAdapter
end

#==================================================================
# module MouseUI
#==================================================================
# @brief The stack of active UI adapters.
module MouseUI
  @stack = []

  module_function

  # @brief The adapter currently receiving mouse input.
  # @return [UIAdapter, nil]
  def current
    return @stack.last
  end

  # @brief Number of adapters on the stack.
  # @return [Integer]
  def depth
    return @stack.length
  end

  # @brief Makes an adapter the active one.
  # @param adapter [UIAdapter]
  # @return [UIAdapter] The adapter.
  def push(adapter)
    @stack.push(adapter)
    adapter.on_push
    return adapter
  end

  # @brief Removes the active adapter.
  # @return [UIAdapter, nil] The removed adapter.
  def pop
    adapter = @stack.pop
    adapter&.on_pop
    return adapter
  end

  # @brief Runs a block with an adapter active, removing it afterwards even if the block raises.
  # @param adapter [UIAdapter]
  # @return [Object] The block's result.
  def with(adapter)
    push(adapter)
    begin
      return yield
    ensure
      pop if current.equal?(adapter)
    end
  end

  # @brief Forgets every adapter (e.g. after a soft reset).
  def clear
    @stack.clear
  end

  # @brief Updates the active adapter. Called by Input.update.
  def update
    return if !MouseInput.available?
    DevLog.guard("Mouse adapter update") { current&.update }
  end

  # @brief Checks whether the active adapter produced a button press this frame.
  # @param button [Integer]
  # @return [Boolean]
  def virtual_trigger?(button)
    adapter = current
    return false if !adapter || !MouseInput.available?
    return DevLog.guard("Mouse adapter trigger?", false) { adapter.trigger?(button) } ? true : false
  end
end

#==================================================================
# Input hooks
#==================================================================
module Input
  class << self
    alias __mouse_trigger? trigger? unless method_defined?(:__mouse_trigger?)
    alias __mouse_update update unless method_defined?(:__mouse_update)

    # @brief Engine trigger check, also true when the active UI adapter pressed the button.
    # @param button [Integer]
    # @return [Boolean]
    def trigger?(button)
      return true if __mouse_trigger?(button)
      return MouseUI.virtual_trigger?(button)
    end

    # @brief Engine input update, then lets the active UI adapter update.
    def update
      __mouse_update
      MouseUI.update
    end
  end
end
