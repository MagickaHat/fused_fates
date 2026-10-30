#================================================================================================
# Pokémon Fused Fates Utilities/Mouse - 001_MouseInput.rb
#================================================================================================

#==================================================================
# module MouseInput
#==================================================================
# @brief Read-only access to the mouse, built on mkxp-z's Input.mouse_* API.
# Everything returns a "no mouse" answer when UtilitySettings::MOUSE_ENABLED is false or the
# engine has no mouse support, so adapters never need to check that themselves.
module MouseInput
  @position      = nil     # Cursor position this frame ([x, y] or nil)
  @last_position = nil     # Cursor position last frame
  @any_click     = false   # Whether a left or right click happened this frame
  @wheel         = 0       # Rate-limited wheel step this frame (-1, 0 or 1)
  @wheel_page    = 0       # Slower rate-limited wheel step this frame
  @wheel_time    = -1.0    # When the last wheel step happened
  @wheel_page_time = -1.0  # When the last page wheel step happened
  @hold_fire     = false   # Whether a held left button repeats this frame
  @hold_next     = 0.0     # When a held left button next repeats

  module_function

  # @brief Records this frame's cursor position, clicks, wheel and held buttons. Called by Input.update.
  def update
    @last_position = @position
    @position = position
    @any_click = available? && (clicked?(Input::MOUSELEFT) || clicked?(Input::MOUSERIGHT))
    update_wheel
    update_hold
  end

  # @brief The current time in seconds.
  # @return [Float]
  def now
    return System.uptime if defined?(System) && System.respond_to?(:uptime)
    return Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # @brief Turns this frame's raw wheel movement into at most one rate-limited step.
  def update_wheel
    @wheel = 0
    @wheel_page = 0
    return if !in_window? || !Input.respond_to?(:scroll_v)
    raw = scroll_delta
    return if raw == 0
    dir = (raw > 0) ? -1 : 1   # Wheel away from the player (positive) moves up
    dir = -dir if UtilitySettings::MOUSE_WHEEL_INVERT
    t = now
    if t - @wheel_time >= UtilitySettings::MOUSE_WHEEL_DELAY
      @wheel = dir
      @wheel_time = t
    end
    if t - @wheel_page_time >= UtilitySettings::MOUSE_WHEEL_PAGE_DELAY
      @wheel_page = dir
      @wheel_page_time = t
    end
  end

  # @brief This frame's raw wheel movement. Input.scroll_v reports the movement since the last
  # update; if it ever reports the same non-zero value for a long time it is treated as a running
  # total instead, so the wheel can never keep scrolling by itself.
  # @return [Integer]
  def scroll_delta
    raw = Input.scroll_v.to_i
    if @scroll_total
      delta = raw - @scroll_last.to_i
      @scroll_last = raw
      return delta
    end
    @scroll_same = (raw != 0 && raw == @scroll_last) ? @scroll_same.to_i + 1 : 0
    @scroll_last = raw
    @scroll_total = true if @scroll_same >= 300   # Five seconds of identical non-zero values
    return 0 if @scroll_total
    return raw
  end

  # @brief Works out whether a held left button repeats this frame.
  def update_hold
    @hold_fire = false
    return if !in_window?
    t = now
    if clicked?
      @hold_fire = true
      @hold_next = t + UtilitySettings::MOUSE_HOLD_DELAY
    elsif pressed? && t >= @hold_next
      @hold_fire = true
      @hold_next = t + UtilitySettings::MOUSE_HOLD_RATE
    end
  end

  # @brief This frame's wheel step for scrolling lists, limited to one per MOUSE_WHEEL_DELAY.
  # @return [Integer] -1 (up), 0 or 1 (down).
  def wheel
    return @wheel
  end

  # @brief This frame's wheel step for changing pages or Pokémon, limited to one per
  # MOUSE_WHEEL_PAGE_DELAY.
  # @return [Integer] -1 (up), 0 or 1 (down).
  def wheel_page
    return @wheel_page
  end

  # @brief Checks whether the left button was clicked this frame, or is being held and repeats
  # this frame (see MOUSE_HOLD_DELAY and MOUSE_HOLD_RATE).
  # @return [Boolean]
  def held_repeat?
    return @hold_fire ? true : false
  end

  # @brief Checks whether the cursor moved (or entered the window) this frame.
  # @return [Boolean]
  def moved?
    return !@position.nil? && @position != @last_position
  end

  # @brief Checks whether a left or right click happened this frame (cheap; cached by update).
  # @return [Boolean]
  def any_click?
    return @any_click ? true : false
  end

  # @brief Checks whether the right mouse button was pressed down this frame inside the window.
  # @return [Boolean]
  def right_clicked?
    return available? && clicked?(Input::MOUSERIGHT)
  end

  # @brief Checks whether the mouse can be used at all.
  # @return [Boolean]
  def available?
    return UtilitySettings::MOUSE_ENABLED && Input.respond_to?(:mouse_x) &&
           Input.respond_to?(:mouse_in_window) && Input.const_defined?(:MOUSELEFT)
  end

  # @brief Checks whether the cursor is over the game window.
  # @return [Boolean]
  def in_window?
    return available? && Input.mouse_in_window ? true : false
  end

  # @brief The cursor position in screen coordinates.
  # @return [Array<Integer>, nil] [x, y], or nil if the cursor is outside the window.
  def position
    return nil if !available?
    return Mouse.getMousePos
  end

  # @brief Checks whether a mouse button was pressed down this frame inside the window.
  # Reads the engine's real trigger state, so it is unaffected by MouseUI's Input hook.
  # @param button [Integer] Input::MOUSELEFT (default), Input::MOUSERIGHT or Input::MOUSEMIDDLE.
  # @return [Boolean]
  def clicked?(button = nil)
    return false if !in_window?
    button ||= Input::MOUSELEFT
    trigger = Input.respond_to?(:__mouse_trigger?) ? :__mouse_trigger? : :trigger?
    return Input.send(trigger, button) ? true : false
  end

  # @brief Checks whether a mouse button is currently held down inside the window.
  # @param button [Integer] Input::MOUSELEFT (default), Input::MOUSERIGHT or Input::MOUSEMIDDLE.
  # @return [Boolean]
  def pressed?(button = nil)
    return false if !in_window?
    return Input.press?(button || Input::MOUSELEFT) ? true : false
  end

  # @brief Checks whether the cursor is over something on screen.
  # Sprites and windows are tested against their on-screen rectangle (viewport offset
  # included, zoom and ox/oy ignored); sprites without a bitmap are never hit.
  # @param target [Rect, Sprite, Window, Array<Integer>] A Rect, a displayed object or [x, y, width, height].
  # @return [Boolean]
  def over?(target)
    pos = position
    return false if !pos
    x, y, w, h = screen_rect(target)
    return false if !x
    return pos[0] >= x && pos[0] < x + w && pos[1] >= y && pos[1] < y + h
  end

  # @brief Works out where something is drawn on screen.
  # @param target [Rect, Sprite, Window, Array<Integer>]
  # @return [Array<Integer>, nil] [x, y, width, height], or nil if it can't be hit.
  def screen_rect(target)
    case target
    when Array then return target[0, 4]
    when Rect  then return [target.x, target.y, target.width, target.height]
    end
    return nil if target.respond_to?(:disposed?) && target.disposed?
    return nil if target.respond_to?(:visible) && !target.visible
    if target.respond_to?(:bitmap) && !target.respond_to?(:windowskin)
      return nil if !target.bitmap || target.bitmap.disposed?
      w = target.src_rect ? target.src_rect.width : target.bitmap.width
      h = target.src_rect ? target.src_rect.height : target.bitmap.height
      x = target.x - (target.respond_to?(:ox) ? target.ox : 0)
      y = target.y - (target.respond_to?(:oy) ? target.oy : 0)
    else
      x, y, w, h = target.x, target.y, target.width, target.height
    end
    vp = target.respond_to?(:viewport) ? target.viewport : nil
    if vp && !vp.disposed?
      x += vp.rect.x - vp.ox
      y += vp.rect.y - vp.oy
    end
    return [x, y, w, h]
  end
end
