#================================================================================================
# Pokémon Fused Fates Utilities/Mouse - 006_ScreenAdapter.rb
#================================================================================================
# Base class for mouse support on screens drawn with sprites (party, summary, PC boxes, battle
# menus...). A screen adapter describes clickable areas ("hotspots") each frame; the base class
# turns hovering, clicking, holding and the wheel into changes the screen already understands.
#
# A hotspot is a Hash:
#   :id    => Anything identifying the spot between frames (defaults to its position in the list).
#   :rect  => [x, y, width, height] in screen coordinates, a Rect, or a sprite.
#   :hover => Proc run once when the cursor moves onto the spot (e.g. set the screen's index).
#   :goto  => Proc returning the key to press to move the screen's cursor one step toward the
#             spot, or nil once it's there. Used for screens whose selection is a local
#             variable: the adapter presses one key per frame while the spot is hovered.
#   :click => What a left click does: a Proc, or Input button(s) to press. Spots with :goto
#             default to Input::USE, pressed once the cursor has arrived.
#   :hover_nav => false to steer toward a :goto spot only when it is clicked, not hovered
#             (e.g. page tabs, which shouldn't change just because the cursor passes over).
#   :hold  => true to repeat :click while the button is held (MOUSE_HOLD_DELAY/RATE).
#   :wheel => Proc called with the wheel step (-1 or 1) while the cursor is over the spot.
#   :page  => true to rate-limit :wheel like a page change (MOUSE_WHEEL_PAGE_DELAY).
# Anything not handled by a spot falls through: #on_wheel gets the wheel, list windows keep
# their own hover/click (ScreenAdapter is a MenuAdapter), and a right click is Back.

#==================================================================
# class ScreenAdapter
#==================================================================
# @brief Hotspot-driven mouse support for a sprite-drawn screen.
class ScreenAdapter < MenuAdapter
  # Presses a hover-driven cursor may make before giving up (e.g. an unreachable spot)
  MAX_NAV_PRESSES = 20

  # @return [Object] The scene this adapter drives.
  attr_reader :scene

  # @param scene [Object] The scene this adapter drives.
  def initialize(scene = nil)
    super(new_windows_only: true)
    @scene = scene
    @hover_id = nil
    @nav_spot = nil
    @nav_presses = 0
    @pending_click = nil
  end

  # @brief The clickable areas this frame. Override in each screen.
  # @return [Array<Hash>]
  def hotspots
    return []
  end

  # @brief Wheel movement over no hotspot. Override to e.g. change page.
  # @param step [Integer] -1 (up) or 1 (down).
  def on_wheel(step); end

  # @brief Which wheel rate this screen uses: :list (MOUSE_WHEEL_DELAY) or :page
  # (MOUSE_WHEEL_PAGE_DELAY, for screens where a wheel step changes a whole page or Pokémon).
  # @return [Symbol]
  def wheel_kind
    return :list
  end

  # @brief Checks whether the cursor is over an item of a list window this adapter handles.
  # @return [Boolean]
  def over_list_item?
    pos = MouseInput.position
    return MenuWindows.windows.any? do |w|
      handles?(w) && MenuWindows.interactive?(w) && MenuWindows.item_at(w, pos)
    end
  end

  # @brief Whether the screen can take mouse input right now (e.g. not during an animation).
  # @return [Boolean]
  def ready?
    return true
  end

  # @brief Reads a scene's instance variable.
  # @param name [Symbol] e.g. :@sprites
  # @return [Object]
  def ivar(name)
    return @scene&.instance_variable_get(name)
  end

  # @brief Gets a sprite from the scene's @sprites hash, if it is still alive.
  # @param key [String]
  # @return [Sprite, nil]
  def sprite(key)
    s = ivar(:@sprites)
    s = s[key] if s
    return nil if !s || (s.respond_to?(:disposed?) && s.disposed?)
    return s
  end

  # @brief Runs the hotspots for this frame. Called once per frame by MouseUI.update.
  def update
    super
    return if !UtilitySettings::MOUSE_SCREENS || !ready?
    spots = DevLog.guard("Mouse hotspots", []) { hotspots } || []
    spots.each_with_index { |s, i| s[:id] = i if !s.key?(:id) }
    spot = spots.find { |s| s[:rect] && MouseInput.over?(s[:rect]) }
    spot = nil if spot && over_list_item?   # List windows on the screen keep their own handling
    if ScreenAdapter.keyboard_used?
      # The keyboard takes over: stop steering the cursor
      @nav_spot = nil
      @pending_click = nil
    elsif spot && (MouseInput.moved? || spot[:id] != @hover_id)
      spot[:hover]&.call
      start_nav(spot[:id]) if spot[:goto] && spot[:hover_nav] != false
    end
    @hover_id = spot ? spot[:id] : nil
    @nav_spot = nil if @nav_spot != @hover_id   # Hover steering stops when the cursor leaves
    # Click
    if spot && (spot[:hold] ? MouseInput.held_repeat? : MouseInput.clicked?)
      if spot[:goto]
        start_nav(spot[:id])
        @pending_click = spot[:id]
      else
        spot[:hover]&.call   # Select it first, in case the keyboard moved away meanwhile
        do_click(spot[:click])
      end
    end
    # Steer a :goto cursor one key per frame; finish a pending click once it has arrived
    target = @pending_click || @nav_spot
    nav = target.nil? ? nil : spots.find { |s| s[:id] == target }
    if !nav || !nav[:goto]
      @nav_spot = nil
      @pending_click = nil
    elsif (key = nav[:goto].call)
      if @nav_presses < MAX_NAV_PRESSES
        press(key)
        @nav_presses += 1
      else
        @nav_spot = nil   # Unreachable; give up
        @pending_click = nil
      end
    else
      do_click(nav.key?(:click) ? nav[:click] : Input::USE) if @pending_click == nav[:id]
      @nav_spot = nil
      @pending_click = nil
    end
    # Wheel
    return if @wheel_used
    if spot && spot[:wheel]
      step = spot[:page] ? MouseInput.wheel_page : MouseInput.wheel
      return if step == 0
      @wheel_used = true
      spot[:wheel].call(step)
    elsif !MenuWindows.windows.any? { |w| handles?(w) && MenuWindows.interactive?(w) }
      step = (wheel_kind == :page) ? MouseInput.wheel_page : MouseInput.wheel
      return if step == 0
      @wheel_used = true
      on_wheel(step)
    end
  end

  # @brief Starts steering the screen's cursor toward a :goto hotspot.
  # @param id [Object] The hotspot's id.
  def start_nav(id)
    @nav_presses = 0 if @nav_spot != id && @pending_click != id
    @nav_spot = id
  end

  # @brief Performs a hotspot's click action.
  # @param click [Proc, Integer, Array<Integer>, nil]
  def do_click(click)
    case click
    when nil  then return
    when Proc then click.call
    else           press(*Array(click))
    end
  end

  # @brief Checks whether a real keyboard direction or confirm key was used this frame.
  # @return [Boolean]
  def self.keyboard_used?
    keys = [Input::UP, Input::DOWN, Input::LEFT, Input::RIGHT, Input::JUMPUP, Input::JUMPDOWN]
    return keys.any? { |k| Input.__mouse_repeat?(k) }
  end

  #----------------------------------------------------------------
  # Navigation helpers for :goto
  #----------------------------------------------------------------
  # @brief Finds the first key on the shortest path from one selection to another, using the
  # screen's own selection function (breadth-first search).
  # @param from [Object] Current selection.
  # @param to [Object] Wanted selection.
  # @param keys [Array<Integer>] Keys to try.
  # @param max_depth [Integer]
  # @yieldparam key [Integer]
  # @yieldparam selection [Object]
  # @yieldreturn [Object] The selection that key leads to.
  # @return [Integer, nil] The key to press, or nil if already there or unreachable.
  def navigate(from, to, keys, max_depth = 16)
    return nil if from == to
    seen = { from => nil }
    queue = [[from, nil, 0]]
    until queue.empty?
      sel, first, depth = queue.shift
      next if depth >= max_depth
      keys.each do |key|
        nxt = DevLog.guard("Mouse navigate") { yield(key, sel) }
        next if nxt.nil? || seen.key?(nxt)
        seen[nxt] = true
        return first || key if nxt == to
        queue.push([nxt, first || key, depth + 1])
      end
    end
    return nil
  end

  # @brief The key that moves a one-dimensional selection toward a target.
  # @param current [Integer]
  # @param target [Integer]
  # @param dec_key [Integer] Key that lowers the selection.
  # @param inc_key [Integer] Key that raises it.
  # @return [Integer, nil] nil once current == target.
  def step_toward(current, target, dec_key, inc_key)
    return nil if current.nil? || current == target
    return (target < current) ? dec_key : inc_key
  end

  # @brief The arrow key that moves an on-screen cursor toward a target area, for screens whose
  # selection can't be read at all. Moves along the axis with the larger distance first.
  # @param cursor [Sprite, Array<Integer>] The screen's cursor (or its rect).
  # @param target [Array<Integer>] The target's [x, y, width, height].
  # @return [Integer, nil] nil once the cursor's centre is inside the target.
  def spatial_step(cursor, target)
    cx, cy, cw, ch = MouseInput.screen_rect(cursor)
    return nil if !cx
    mx = cx + (cw / 2)
    my = cy + (ch / 2)
    tx, ty, tw, th = target
    dx = (mx < tx) ? 1 : (mx >= tx + tw) ? -1 : 0
    dy = (my < ty) ? 1 : (my >= ty + th) ? -1 : 0
    return nil if dx == 0 && dy == 0
    dist_x = (dx == 0) ? 0 : [(tx - mx).abs, (tx + tw - mx).abs].min
    dist_y = (dy == 0) ? 0 : [(ty - my).abs, (ty + th - my).abs].min
    if dist_y >= dist_x && dy != 0
      return (dy < 0) ? Input::UP : Input::DOWN
    end
    return (dx < 0) ? Input::LEFT : Input::RIGHT
  end

  # @brief An on-screen rect for a sprite whose bitmap holds several frames stacked vertically
  # (only the top part is shown).
  # @param sprite [Sprite]
  # @param parts [Integer] How many frames are stacked.
  # @return [Array<Integer>, nil]
  def part_rect(sprite, parts = 2)
    return nil if !sprite || !sprite.bitmap || sprite.bitmap.disposed?
    return [sprite.x - sprite.ox, sprite.y - sprite.oy, sprite.bitmap.width, sprite.bitmap.height / parts]
  end
end

#==================================================================
# module ScreenMouse
#==================================================================
# @brief Helpers for wrapping screen methods in an adapter.
module ScreenMouse
  module_function

  # @brief Wraps instance methods of a class so they run with an adapter active.
  # @param klass [Class]
  # @param adapter_class [Class] Created with the object whose method runs.
  # @param names [Array<Symbol>]
  def wrap(klass, adapter_class, *names)
    names.each do |name|
      next if !klass.method_defined?(name)
      original = :"__mouse_screen_#{name}"
      next if klass.method_defined?(original)
      klass.send(:alias_method, original, name)
      klass.send(:define_method, name) do |*args, **kwargs, &block|
        next send(original, *args, **kwargs, &block) if !UtilitySettings::MOUSE_SCREENS
        next MouseUI.with(adapter_class.new(self)) { send(original, *args, **kwargs, &block) }
      end
    end
  end
end
