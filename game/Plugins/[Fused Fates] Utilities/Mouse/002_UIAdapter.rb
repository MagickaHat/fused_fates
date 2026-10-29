#================================================================================================
# Pokémon Fused Fates Utilities/Mouse - 002_UIAdapter.rb
#================================================================================================
# Mouse support works through UI adapters. An adapter turns what the mouse did this frame
# into the buttons a screen already listens for (Input::USE, Input::BACK, ...), so existing
# Essentials loops gain mouse support without being rewritten.
#
# Adapters live on a stack (MouseUI); only the top one is asked. While it is active,
# Input.trigger?(button) is also true whenever the adapter says the mouse produced that button.
# When nothing is pushed, an ambient MenuAdapter is used, so every list window
# (SpriteWindow_Selectable and its subclasses: choices, pause menu, bag, mart, options...)
# supports hover and click automatically, and a right click acts as Back everywhere.
#
# Adding mouse support to a new screen:
#   - Screens built from list windows need nothing: they already work.
#   - Sprite-based screens (party, summary, battle menus...): subclass UIAdapter, override
#     #trigger? (and #update for per-frame work such as hover), then run the screen's main
#     loop inside MouseUI.with(MyAdapter.new) { ... }, usually by aliasing the method that
#     runs it (see 003_DialogueAdapter.rb and 004_MenuAdapter.rb).
#   - Wrap anything that must ignore the mouse in a BlockingAdapter.

#==================================================================
# class UIAdapter
#==================================================================
# @brief Base class for objects that translate mouse input into button presses.
# On its own it only maps a right click to Input::BACK (see UtilitySettings::MOUSE_RIGHT_CLICK_BACK).
class UIAdapter
  # @brief Checks whether the mouse pressed a button this frame.
  # Only asked on frames where a mouse button was clicked. Subclasses should call super for
  # buttons they don't handle themselves.
  # @param button [Integer] An Input button constant such as Input::USE.
  # @return [Boolean]
  def trigger?(button)
    return button == Input::BACK && UtilitySettings::MOUSE_RIGHT_CLICK_BACK && MouseInput.right_clicked?
  end

  # @brief Called once per frame by Input.update while the adapter is the current one.
  def update; end

  # @brief Called when the adapter is pushed onto the stack.
  def on_push; end

  # @brief Called when the adapter is popped off the stack.
  def on_pop; end
end

#==================================================================
# class BlockingAdapter
#==================================================================
# @brief An adapter that maps nothing, not even right click. Push it over screens where
# clicks must never count as button presses.
class BlockingAdapter < UIAdapter
  # @brief Never reports a press.
  # @param button [Integer]
  # @return [Boolean]
  def trigger?(button)
    return false
  end
end

#==================================================================
# module MouseUI
#==================================================================
# @brief The stack of active UI adapters.
module MouseUI
  @stack   = []
  @ambient = nil   # Adapter used when the stack is empty

  module_function

  # @brief The adapter currently receiving mouse input.
  # @return [UIAdapter] The top of the stack, or the ambient adapter if nothing is pushed.
  def current
    return @stack.last || ambient
  end

  # @brief The adapter used when nothing is pushed: a MenuAdapter if UtilitySettings::MOUSE_MENUS
  # is on, otherwise a plain UIAdapter (right click = Back only).
  # @return [UIAdapter]
  def ambient
    return @ambient if @ambient
    @ambient = (UtilitySettings::MOUSE_MENUS && defined?(MenuAdapter)) ? MenuAdapter.new : UIAdapter.new
    return @ambient
  end

  # @brief Number of adapters pushed onto the stack (the ambient adapter isn't counted).
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
      pop if @stack.last.equal?(adapter)
    end
  end

  # @brief Forgets every adapter (e.g. after a soft reset).
  def clear
    @stack.clear
  end

  # @brief Updates the mouse state and the active adapter. Called by Input.update.
  def update
    MouseInput.update
    MenuWindows.next_frame if defined?(MenuWindows)
    return if !MouseInput.available?
    DevLog.guard("Mouse adapter update") { current.update }
  end

  # @brief Checks whether the active adapter produced a button press this frame.
  # @param button [Integer]
  # @return [Boolean]
  def virtual_trigger?(button)
    return false if !MouseInput.any_click?
    adapter = current
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

    # @brief Engine input update, then lets the mouse state and active UI adapter update.
    def update
      __mouse_update
      MouseUI.update
    end
  end
end
