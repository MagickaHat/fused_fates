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

  module_function

  # @brief Records this frame's cursor position and clicks. Called by Input.update.
  def update
    @last_position = @position
    @position = position
    @any_click = available? && (clicked?(Input::MOUSELEFT) || clicked?(Input::MOUSERIGHT))
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
