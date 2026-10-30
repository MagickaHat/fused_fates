#================================================================================================
# Pokémon Fused Fates Utilities/Mouse - 005_OptionsMouse.rb
#================================================================================================
# Mouse support for option values in the Options screen (Window_PokemonOption):
#   - Wheel over a value changes it one step (up = next, down = previous).
#   - Click a choice (e.g. "Fast") to pick it.
#   - Click or drag along a slider to set it.
#   - Click the left/right half of a number value to step it; holding repeats calmly.
# The wheel over option names scrolls the list as in every other list window.

#==================================================================
# class Window_PokemonOption
#==================================================================
class Window_PokemonOption
  alias __mouse_options_update update unless method_defined?(:__mouse_options_update)

  # @brief Updates the window as usual, then applies value clicks and slider drags.
  def update
    __mouse_options_update
    DevLog.guard("Mouse options") { mouse_value_input }
  end

  # @brief Changes the value under the cursor by one step with the wheel.
  # Called by MenuAdapter#wheel; returns false to let the wheel scroll the list instead.
  # @param step [Integer] -1 (wheel up) or 1 (wheel down).
  # @return [Boolean] Whether the wheel was used.
  def mouse_wheel_value(step)
    hit = mouse_value_hit
    return false if !hit
    row = hit[0]
    mouse_select_row(row)
    value = (step < 0) ? @options[row].next(self[row]) : @options[row].prev(self[row])
    mouse_set_value(row, value)
    return true
  end

  private

  # @brief Checks whether the current adapter lets this window take mouse input.
  # @return [Boolean]
  def mouse_options_active?
    return false if !UtilitySettings::MOUSE_MENUS || !MouseInput.available?
    adapter = MouseUI.current
    return false if !adapter.is_a?(MenuAdapter) || !adapter.handles?(self)
    return MenuWindows.interactive?(self)
  end

  # @brief Handles clicks, holds and drags on the value part of a row.
  def mouse_value_input
    return if !mouse_options_active?
    dragging = MouseInput.pressed? && MouseInput.moved? && @mouse_slider_row
    @mouse_slider_row = nil if !MouseInput.pressed?
    return if !MouseInput.held_repeat? && !dragging
    hit = mouse_value_hit
    return if !hit
    row, lx, area = hit
    option = @options[row]
    if dragging
      return if row != @mouse_slider_row
      mouse_set_value(row, mouse_slider_value(option, lx, area))
      return
    end
    first_press = MouseInput.clicked?
    mouse_select_row(row)
    case option
    when SliderOption
      return if !first_press
      @mouse_slider_row = row
      mouse_set_value(row, mouse_slider_value(option, lx, area))
    when NumberOption
      right = lx >= area[0] + (area[1] / 2)
      mouse_set_value(row, right ? option.next(self[row]) : option.prev(self[row]))
    when EnumOption
      return if !first_press
      choice = mouse_enum_choice(row, lx, area)
      mouse_set_value(row, choice) if choice
    else
      mouse_set_value(row, option.next(self[row])) if first_press
    end
  end

  # @brief Highlights a row, keeping the view where it is.
  # @param row [Integer]
  def mouse_select_row(row)
    return if self.index == row
    @mouse_pin = MenuWindows.shown_top_row(self)
    self.index = row
  end

  # @brief Stores a new value and tells the Options scene to apply it.
  # @param row [Integer]
  # @param value [Integer]
  def mouse_set_value(row, value)
    return if value.nil? || value == self[row]
    self[row] = value
    @value_changed = true
  end

  # @brief Finds the option row and value area under the cursor.
  # @return [Array, nil] [row, local x, [area x, area width]], or nil if the cursor isn't over a value.
  def mouse_value_hit
    pos = MouseInput.position
    return nil if !pos || !MouseInput.over?(self)
    row = MenuWindows.item_at(self, pos)
    return nil if !row || row >= @options.length
    wx, = MouseInput.screen_rect(self)
    lx = pos[0] - wx - self.leftEdge
    rect = itemRect(row)
    rect = Rect.new(rect.x + 16, rect.y, rect.width - 16, rect.height)   # Matches drawCursor
    optionwidth = rect.width * 9 / 20
    area_x = rect.x + optionwidth
    area_w = rect.width - optionwidth
    return nil if lx < area_x
    return [row, lx, [area_x, area_w, rect]]
  end

  # @brief Works out which choice of an EnumOption was clicked, using drawItem's layout.
  # @return [Integer, nil]
  def mouse_enum_choice(row, lx, area)
    values = @options[row].values
    return nil if values.length <= 1
    rect = area[2]
    optionwidth = rect.width * 9 / 20
    widths = values.map { |v| self.contents.text_size(v).width }
    spacing = (rect.width - rect.x - optionwidth - widths.sum) / (values.length - 1)
    spacing = 0 if spacing < 0
    xpos = optionwidth + rect.x
    best = nil
    best_dist = nil
    widths.each_with_index do |w, i|
      return i if lx >= xpos && lx < xpos + w
      dist = [(lx - xpos).abs, (lx - (xpos + w)).abs].min
      best, best_dist = i, dist if !best_dist || dist < best_dist
      xpos += w + spacing
    end
    return best   # Between two choices: the nearest one
  end

  # @brief Works out a slider's value from the cursor position, using drawItem's layout.
  # @return [Integer] The stored value (offset from the lowest value).
  def mouse_slider_value(option, lx, area)
    rect = area[2]
    optionwidth = rect.width * 9 / 20
    label = sprintf(" %d", option.highest_value)
    length = rect.width - rect.x - optionwidth - self.contents.text_size(label).width
    xpos = optionwidth + rect.x
    span = option.highest_value - option.lowest_value
    fraction = ((lx - xpos).to_f / [length - 8, 1].max).clamp(0.0, 1.0)
    interval = [option.instance_variable_get(:@interval).to_i, 1].max
    value = (fraction * span / interval).round * interval
    return value.clamp(0, span)
  end
end
