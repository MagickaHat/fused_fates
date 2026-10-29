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
#   - Sprite-based screens: subclass ScreenAdapter (006_ScreenAdapter.rb) and describe the
#     screen's clickable areas in #hotspots, then attach it with ScreenMouse.wrap(SceneClass,
#     MyAdapter, :loop_method), or MouseUI.attach_scene when another plugin replaces the loop
#     (see 007-009 for the Party, Summary, PC, battle and Pokédex screens).
#   - Adapters can press keys for a frame (UIAdapter#press), so screens that keep their
#     selection in local variables are driven through their own key handling.
#   - Wrap anything that must ignore the mouse in a BlockingAdapter.

#==================================================================
# class UIAdapter
#==================================================================
# @brief Base class for objects that translate mouse input into button presses.
# On its own it only maps a right click to Input::BACK (see UtilitySettings::MOUSE_RIGHT_CLICK_BACK).
class UIAdapter
  # @brief Presses buttons for the rest of this frame: Input.trigger? and Input.repeat? both
  # report them until the next Input.update. Used to drive screens whose selection can only be
  # changed through their own key handling (one key per frame).
  # @param buttons [Array<Integer>] Input button constants.
  def press(*buttons)
    @presses ||= []
    buttons.flatten.each { |b| @presses.push(b) if b && !@presses.include?(b) }
  end

  # @brief Checks whether #press pressed a button this frame.
  # @param button [Integer]
  # @return [Boolean]
  def pressed?(button)
    return @presses ? @presses.include?(button) : false
  end

  # @brief Forgets last frame's presses. Called by MouseUI.update before #update.
  def clear_presses
    @presses&.clear
  end

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
      remove(adapter)
    end
  end

  # @brief Removes one adapter wherever it is on the stack, leaving the others in place.
  # @param adapter [UIAdapter]
  def remove(adapter)
    i = @stack.rindex { |a| a.equal?(adapter) }
    return if !i
    @stack.delete_at(i)
    adapter.on_pop
  end

  # @brief Forgets every adapter (e.g. after a soft reset).
  def clear
    @stack.clear
  end

  # @brief Saves a method's current version under another name before it is wrapped.
  # F12 makes mkxp-z run every script again: Essentials restores its original methods, then the
  # plugins run again. So the saved copy is refreshed whenever the current method is not already
  # the mouse wrapper (re-saving the wrapper as its own original would make it call itself), and
  # callers always define the wrapper again afterwards.
  # @param klass [Class]
  # @param name [Symbol] The method to wrap.
  # @param original [Symbol] Name to save the current version under.
  # @param file [String] File that defines the wrapper, e.g. "002_UIAdapter.rb".
  def save_original(klass, name, original, file)
    src = klass.instance_method(name).source_location&.first.to_s
    return if klass.method_defined?(original) && src.end_with?(file)
    klass.send(:alias_method, original, name)
  end

  # @brief Gives a scene class an adapter for as long as it is open, by pushing one when any
  # start method runs and removing it when the finish method runs. Used for scenes whose input
  # loops other plugins replace, since start/end methods are rarely overridden.
  # @param klass [Class] The scene class.
  # @param adapter_class [Class] A UIAdapter subclass; created with the scene as its argument.
  # @param start [Array<Symbol>] Methods that open the scene.
  # @param finish [Symbol] Method that closes the scene.
  def attach_scene(klass, adapter_class, start: [:pbStartScene], finish: :pbEndScene)
    start.each do |name|
      next if !klass.method_defined?(name)
      original = :"__mouse_attach_#{name}"
      save_original(klass, name, original, "002_UIAdapter.rb")
      klass.send(:define_method, name) do |*args, **kwargs, &block|
        ret = send(original, *args, **kwargs, &block)
        if UtilitySettings::MOUSE_SCREENS && !@mouse_adapter
          @mouse_adapter = MouseUI.push(adapter_class.new(self))
        end
        next ret
      end
    end
    return if !klass.method_defined?(finish)
    original = :"__mouse_attach_#{finish}"
    save_original(klass, finish, original, "002_UIAdapter.rb")
    klass.send(:define_method, finish) do |*args, **kwargs, &block|
      begin
        next send(original, *args, **kwargs, &block)
      ensure
        MouseUI.remove(@mouse_adapter) if @mouse_adapter
        @mouse_adapter = nil
      end
    end
  end

  # @brief Updates the mouse state and the active adapter. Called by Input.update.
  def update
    MouseInput.update
    MenuWindows.next_frame if defined?(MenuWindows)
    adapter = current
    adapter.clear_presses
    return if !MouseInput.available?
    DevLog.guard("Mouse adapter update") { adapter.update }
  end

  # @brief Checks whether the active adapter produced a button press this frame.
  # @param button [Integer]
  # @return [Boolean]
  def virtual_trigger?(button)
    adapter = current
    return true if adapter.pressed?(button)
    return false if !MouseInput.any_click?
    return DevLog.guard("Mouse adapter trigger?", false) { adapter.trigger?(button) } ? true : false
  end

  # @brief Checks whether the active adapter pressed a button this frame (see UIAdapter#press).
  # @param button [Integer]
  # @return [Boolean]
  def virtual_repeat?(button)
    return current.pressed?(button)
  end
end

#==================================================================
# Input hooks
#==================================================================
module Input
  class << self
    alias __mouse_trigger? trigger? unless method_defined?(:__mouse_trigger?)
    alias __mouse_repeat? repeat? unless method_defined?(:__mouse_repeat?)
    alias __mouse_update update unless method_defined?(:__mouse_update)

    # @brief Engine trigger check, also true when the active UI adapter pressed the button.
    # @param button [Integer]
    # @return [Boolean]
    def trigger?(button)
      return true if __mouse_trigger?(button)
      return MouseUI.virtual_trigger?(button)
    end

    # @brief Engine repeat check, also true when the active UI adapter pressed the button.
    # @param button [Integer]
    # @return [Boolean]
    def repeat?(button)
      return true if __mouse_repeat?(button)
      return MouseUI.virtual_repeat?(button)
    end

    # @brief Engine input update, then lets the mouse state and active UI adapter update.
    def update
      __mouse_update
      MouseUI.update
    end
  end
end
