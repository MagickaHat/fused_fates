#================================================================================================
# Pokémon Fused Fates Utilities/Mouse - 004_MenuAdapter.rb
#================================================================================================

#==================================================================
# module MenuWindows
#==================================================================
# @brief Keeps track of the list windows (SpriteWindow_Selectable and subclasses) on screen.
# Windows register themselves every time they update; both this frame's and last frame's
# windows are kept, so input checks work whether a screen updates its windows before or after
# reading input.
module MenuWindows
  @current  = []   # Windows updated since the last Input.update
  @previous = []   # Windows updated the frame before
  @serial   = 0    # Number of list windows created so far

  module_function

  # @brief Gives a newly created window its creation number. Called by SpriteWindow_Selectable#initialize.
  # @param window [SpriteWindow_Selectable]
  def stamp(window)
    @serial += 1
    window.instance_variable_set(:@mouse_serial, @serial)
  end

  # @brief Number of list windows created so far; windows made later have a higher serial.
  # @return [Integer]
  def serial
    return @serial
  end

  # @brief A window's creation number (0 for windows made before this plugin loaded).
  # @param window [SpriteWindow_Selectable]
  # @return [Integer]
  def serial_of(window)
    return window.instance_variable_get(:@mouse_serial) || 0
  end

  # @brief Records that a window updated this frame.
  # @param window [SpriteWindow_Selectable]
  def register(window)
    @current.push(window) if !@current.any? { |w| w.equal?(window) }
  end

  # @brief Starts a new frame. Called by Input.update.
  def next_frame
    @previous = @current
    @current = []
  end

  # @brief Every live window seen this frame or the last.
  # @return [Array<SpriteWindow_Selectable>]
  def windows
    list = @current.dup
    @previous.each { |w| list.push(w) if !list.any? { |c| c.equal?(w) } }
    return list.reject { |w| w.disposed? }
  end

  # @brief Checks whether a window currently accepts input, using the same conditions as the
  # keyboard handling in SpriteWindow_Selectable#update, plus being visible.
  # @param window [SpriteWindow_Selectable]
  # @return [Boolean]
  def interactive?(window)
    return false if window.disposed? || !window.visible || !window.active
    return false if window.itemCount <= 0 || window.index < 0
    return false if window.instance_variable_get(:@ignore_input)
    vp = window.viewport
    return false if vp && (vp.disposed? || (vp.respond_to?(:visible) && !vp.visible))
    return true
  end

  # @brief Checks whether any list window is currently accepting input.
  # @yieldparam window [SpriteWindow_Selectable] Optional filter; only windows it accepts count.
  # @return [Boolean]
  def any_interactive?
    return windows.any? { |w| interactive?(w) && (!block_given? || yield(w)) }
  end

  # @brief The interactive window under the cursor that is drawn on top.
  # @yieldparam window [SpriteWindow_Selectable] Optional filter; only windows it accepts count.
  # @return [SpriteWindow_Selectable, nil]
  def focused
    hits = windows.select { |w| interactive?(w) && (!block_given? || yield(w)) && MouseInput.over?(w) }
    return hits.max_by { |w| [w.viewport ? w.viewport.z : 0, w.z] }
  end

  # @brief Finds the visible item of a window under a screen position.
  # @param window [SpriteWindow_Selectable]
  # @param pos [Array<Integer>] [x, y] in screen coordinates.
  # @return [Integer, nil] The item's index, or nil if no item is there.
  def item_at(window, pos)
    return nil if !pos
    wx, wy, = MouseInput.screen_rect(window)
    return nil if !wx
    x = pos[0] - wx - window.leftEdge
    y = pos[1] - wy - window.topEdge
    first = window.top_item
    last = [first + window.page_item_max, window.itemCount - 1].min
    (first..last).each do |i|
      r = window.itemRect(i)
      next if r.width <= 0 || r.height <= 0
      return i if x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height
    end
    return nil
  end

  # @brief Highest top row a window can scroll to.
  # @param window [SpriteWindow_Selectable]
  # @return [Integer]
  def max_top_row(window)
    return [window.row_max - window.page_row_max, 0].max
  end

  # @brief Adjusts a pinned top row so the highlighted row stays on screen. The view moves by
  # as little as possible, unlike Essentials' own scrolling, which centres the highlight.
  # @param window [SpriteWindow_Selectable]
  # @param pin [Integer] Wanted top row.
  # @return [Integer] The top row to use.
  def pin_for(window, pin)
    cols = [window.columns, 1].max
    rows = [window.page_row_max, 1].max
    row = window.index / cols
    pin = row if row < pin
    pin = row - rows + 1 if row > pin + rows - 1
    return pin.clamp(0, max_top_row(window))
  end

  # @brief The top row a window is showing (its pinned row while the mouse controls it).
  # @param window [SpriteWindow_Selectable]
  # @return [Integer]
  def shown_top_row(window)
    return window.instance_variable_get(:@mouse_pin) || window.top_row
  end

  # @brief Scrolls a window's view by whole rows, keeping the highlight on screen.
  # If the cursor is over the list, the item now under it becomes highlighted.
  # @param window [SpriteWindow_Selectable]
  # @param rows [Integer] Negative scrolls up.
  # @return [Boolean] Whether the view moved.
  def scroll(window, rows)
    old_top = shown_top_row(window)
    new_top = (old_top + rows).clamp(0, max_top_row(window))
    return false if new_top == old_top
    window.instance_variable_set(:@mouse_pin, new_top)
    cols = [window.columns, 1].max
    last_row = new_top + window.page_row_max - 1
    row = window.index / cols
    index = window.index
    index = (new_top * cols) + (index % cols) if row < new_top
    index = (last_row * cols) + (index % cols) if row > last_row
    index = index.clamp(0, window.itemCount - 1)
    if window.index == index
      window.send(:priv_update_cursor_rect, true)   # Same highlight; redraw the moved view
    else
      window.index = index
    end
    under = item_at(window, MouseInput.position) if MouseInput.over?(window)
    window.index = under if under && under != window.index
    return true
  end

  # @brief Moves a short list's highlight by one row (used by the wheel when nothing scrolls).
  # @param window [SpriteWindow_Selectable]
  # @param rows [Integer] -1 or 1.
  # @return [Boolean] Whether the highlight moved.
  def step(window, rows)
    cols = [window.columns, 1].max
    index = (window.index + (rows * cols)).clamp(0, window.itemCount - 1)
    return false if index == window.index
    window.instance_variable_set(:@mouse_pin, shown_top_row(window))
    window.index = index
    return true
  end

  # @brief Works out whether the cursor is on one of a window's scroll arrows (or the border
  # strip they sit in) and whether that way can scroll.
  # @param window [SpriteWindow_Selectable]
  # @return [Integer, nil] -1 for the up arrow, 1 for the down arrow, nil otherwise.
  def arrow_at(window)
    return nil if max_top_row(window) == 0
    wx, wy, ww, wh = MouseInput.screen_rect(window)
    return nil if !wx
    top = shown_top_row(window)
    edge = [window.respond_to?(:topEdge) ? window.topEdge : 16, 16].max
    up = window.instance_variable_get(:@uparrow)
    down = window.instance_variable_get(:@downarrow)
    if top > 0 && (MouseInput.over?([wx, wy, ww, edge]) || (up && MouseInput.over?(up)))
      return -1
    end
    if top < max_top_row(window) &&
       (MouseInput.over?([wx, wy + wh - edge, ww, edge]) || (down && MouseInput.over?(down)))
      return 1
    end
    return nil
  end
end

#==================================================================
# class MenuAdapter
#==================================================================
# @brief Mouse support for list windows: hovering an item highlights it, a left click on an
# item picks it (as Input::USE), and a right click acts as Input::BACK.
# This is MouseUI's ambient adapter, so every list window works with the mouse by default.
class MenuAdapter < UIAdapter
  # @param click_anywhere_when_hidden [Boolean] Whether a left click anywhere counts as
  # Input::USE while no list is shown (e.g. battle text still printing before Yes/No appears).
  # @param new_windows_only [Boolean] Whether to ignore windows created before the adapter was
  # pushed, so a choice list opened over another menu (e.g. "Toss?" over the Bag) can't be
  # confirmed by clicking the menu behind it.
  def initialize(click_anywhere_when_hidden: false, new_windows_only: false)
    super()
    @click_anywhere_when_hidden = click_anywhere_when_hidden
    @new_windows_only = new_windows_only
    @min_serial = 0
  end

  # @brief Remembers which windows already existed, for new_windows_only.
  def on_push
    @min_serial = MenuWindows.serial if @new_windows_only
  end

  # @brief Checks whether this adapter responds to a window.
  # @param window [SpriteWindow_Selectable]
  # @return [Boolean]
  def handles?(window)
    return MenuWindows.serial_of(window) > @min_serial
  end

  # @brief The window under the cursor this adapter responds to.
  # @return [SpriteWindow_Selectable, nil]
  def focused_window
    return MenuWindows.focused { |w| handles?(w) }
  end

  # @brief Moves a window's highlight onto the item under the cursor. Only reacts when the
  # mouse moves, so a resting cursor never fights the arrow keys.
  # Called from SpriteWindow_Selectable#update.
  # @param window [SpriteWindow_Selectable]
  def hover(window)
    return if !MouseInput.moved? || !handles?(window) || !MenuWindows.interactive?(window)
    return if !focused_window.equal?(window)
    index = MenuWindows.item_at(window, MouseInput.position)
    return if !index || index == window.index
    # Pin the view so the list doesn't re-centre (and scroll away) under the cursor
    window.instance_variable_set(:@mouse_pin, MenuWindows.shown_top_row(window))
    window.index = index
    pbPlayCursorSE if defined?(pbPlayCursorSE)
  end

  # @brief Clears the once-per-frame wheel flag. Called once per frame by MouseUI.update.
  def update
    super
    @wheel_used = false
  end

  # @brief Everything the mouse does to a list window each frame: hover, wheel and the scroll
  # arrows. Called from SpriteWindow_Selectable#update.
  # @param window [SpriteWindow_Selectable]
  def window_frame(window)
    hover(window)
    return if !handles?(window) || !MenuWindows.interactive?(window)
    wheel(window)
    arrows(window)
  end

  # @brief Applies this frame's wheel step to the list under the cursor (or to the only list
  # on screen). Long lists scroll one row; short lists move the highlight one row.
  # @param window [SpriteWindow_Selectable]
  def wheel(window)
    step = MouseInput.wheel
    return if step == 0 || @wheel_used
    target = focused_window
    if !target
      lists = MenuWindows.windows.select { |w| handles?(w) && MenuWindows.interactive?(w) }
      target = lists[0] if lists.length == 1
    end
    return if !target.equal?(window)
    @wheel_used = true
    if window.respond_to?(:mouse_wheel_value) && window.mouse_wheel_value(step)
      return   # The window used the wheel itself (e.g. Options values)
    end
    old_index = window.index
    if MenuWindows.max_top_row(window) > 0
      MenuWindows.scroll(window, step)
    else
      MenuWindows.step(window, step)
    end
    pbPlayCursorSE if window.index != old_index && defined?(pbPlayCursorSE)
  end

  # @brief Clicking or holding a list's up/down arrow scrolls it one row at a time, at the calm
  # MOUSE_HOLD_DELAY / MOUSE_HOLD_RATE pace. This keeps long lists usable without a wheel.
  # @param window [SpriteWindow_Selectable]
  def arrows(window)
    return if !MouseInput.held_repeat?
    dir = MenuWindows.arrow_at(window)
    return if !dir
    old_index = window.index
    MenuWindows.scroll(window, dir)
    pbPlayCursorSE if window.index != old_index && defined?(pbPlayCursorSE)
  end

  # @brief A left click on an item selects it and counts as Input::USE.
  # @param button [Integer]
  # @return [Boolean]
  def trigger?(button)
    return super if button != Input::USE
    return false if !MouseInput.clicked?
    window = focused_window
    if window
      index = MenuWindows.item_at(window, MouseInput.position)
      return false if !index
      window.index = index if window.index != index
      return true
    end
    return @click_anywhere_when_hidden && !MenuWindows.any_interactive? { |w| handles?(w) }
  end
end

#==================================================================
# List window hook
#==================================================================
class SpriteWindow_Selectable
  alias __mouse_initialize initialize unless private_method_defined?(:__mouse_initialize)
  alias __mouse_update update unless method_defined?(:__mouse_update)

  # @brief Creates the window as usual and records its creation order (see MenuAdapter new_windows_only).
  def initialize(*args, **kwargs, &block)
    __mouse_initialize(*args, **kwargs, &block)
    MenuWindows.stamp(self)
  end

  # Keys that move a list's highlight; using any of them hands scrolling back to Essentials
  MOUSE_NAV_KEYS = [Input::UP, Input::DOWN, Input::LEFT, Input::RIGHT,
                    Input::JUMPUP, Input::JUMPDOWN].freeze

  # @brief Updates the window as usual, then lets the mouse move its highlight and scroll it.
  def update
    if @mouse_pin && MOUSE_NAV_KEYS.any? { |k| Input.__mouse_repeat?(k) }
      @mouse_pin = nil   # Keyboard in use: go back to Essentials' centred scrolling
    end
    __mouse_update
    return if !UtilitySettings::MOUSE_MENUS || !MouseInput.available? || disposed?
    MenuWindows.register(self)
    adapter = MouseUI.current
    return if !adapter.respond_to?(:window_frame)
    DevLog.guard("Mouse menu frame") { adapter.window_frame(self) }
  end

  private

  alias __mouse_priv_update_cursor_rect priv_update_cursor_rect unless private_method_defined?(:__mouse_priv_update_cursor_rect)

  # @brief Positions the cursor as usual, except while the mouse has pinned the view: then the
  # list only scrolls when the highlight would leave the screen, and by as little as possible.
  # @param force [Boolean] Whether to redraw the contents.
  def priv_update_cursor_rect(force = false)
    return __mouse_priv_update_cursor_rect(force) if !@mouse_pin || @index < 0
    old_top = self.top_row
    __mouse_priv_update_cursor_rect(false)
    @mouse_pin = MenuWindows.pin_for(self, @mouse_pin)
    self.top_row = @mouse_pin if self.top_row != @mouse_pin
    cursor_width = (self.width - self.borderX) / @column_max
    x = @index % @column_max * (cursor_width + @column_spacing)
    y = (@index / @column_max * @row_height) - @virtualOy
    self.cursor_rect.set(x, y, cursor_width, @row_height)
    refresh if force || self.top_row != old_top
  end
end

#==================================================================
# Choice lists
#==================================================================
# Choices opened from a message would otherwise inherit the DialogueAdapter, which turns any
# click into Input::USE; push a MenuAdapter so only clicks on an option pick it.
alias __mouse_pbShowCommands pbShowCommands unless defined?(__mouse_pbShowCommands)
alias __mouse_pbShowCommandsWithHelp pbShowCommandsWithHelp unless defined?(__mouse_pbShowCommandsWithHelp)

# @brief Shows a choice list; hover highlights an option and a left click picks it.
def pbShowCommands(*args, &block)
  return __mouse_pbShowCommands(*args, &block) if !UtilitySettings::MOUSE_MENUS
  return MouseUI.with(MenuAdapter.new(new_windows_only: true)) { __mouse_pbShowCommands(*args, &block) }
end

# @brief Shows a choice list with help text; hover highlights an option and a left click picks it.
def pbShowCommandsWithHelp(*args, &block)
  return __mouse_pbShowCommandsWithHelp(*args, &block) if !UtilitySettings::MOUSE_MENUS
  return MouseUI.with(MenuAdapter.new(new_windows_only: true)) { __mouse_pbShowCommandsWithHelp(*args, &block) }
end

# Keep these public like the originals; Essentials calls Kernel.pbShowCommands for message choices
Object.send(:public, :pbShowCommands, :pbShowCommandsWithHelp)

class Battle::Scene
  alias __mouse_pbShowCommands pbShowCommands unless method_defined?(:__mouse_pbShowCommands)

  # @brief Shows a battle question with choices (e.g. Yes/No). A click anywhere advances the
  # question text; once the choices appear, hover and click pick one.
  def pbShowCommands(*args, &block)
    return __mouse_pbShowCommands(*args, &block) if !UtilitySettings::MOUSE_MENUS
    adapter = MenuAdapter.new(click_anywhere_when_hidden: UtilitySettings::MOUSE_DIALOGUE,
                              new_windows_only: true)
    return MouseUI.with(adapter) { __mouse_pbShowCommands(*args, &block) }
  end
end
