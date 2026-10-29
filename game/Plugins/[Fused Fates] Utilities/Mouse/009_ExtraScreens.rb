#================================================================================================
# Pokémon Fused Fates Utilities/Mouse - 009_ExtraScreens.rb
#================================================================================================
# Mouse support for the Pokédex (entry pages, forms, search), Region Map, Trainer Card, Move
# Relearner and the on-screen name entry grid. Pokédex lists and the Jukebox are list windows,
# which already work with the mouse.

#==================================================================
# Pokédex entry
#==================================================================
# @brief Pokédex entry (PokemonPokedexInfo_Scene#pbScene): click the INFO / AREA / FORMS tabs or
# the arrows beside them to change page, wheel to change species, click the Forms page to choose
# a form.
class PokedexEntryMouseAdapter < ScreenAdapter
  TABS = [[48, 0, 72, 32], [136, 0, 72, 32], [226, 0, 84, 32]].freeze   # From bg_info
  LEFT_ARROW  = [16, 0, 30, 32].freeze
  RIGHT_ARROW = [314, 0, 30, 32].freeze
  BODY = [0, 40, 512, 344].freeze

  # @return [Symbol]
  def wheel_kind
    return :page
  end

  # @return [Array<Hash>]
  def hotspots
    spots = TABS.each_with_index.map do |rect, i|
      { id: [:tab, i], rect: rect, hover_nav: false, click: nil,
        goto: proc { step_toward(ivar(:@page), i + 1, Input::LEFT, Input::RIGHT) } }
    end
    spots.push({ id: :left, rect: LEFT_ARROW, click: Input::LEFT })
    spots.push({ id: :right, rect: RIGHT_ARROW, click: Input::RIGHT })
    spots.push({ id: :forms, rect: BODY, click: Input::USE }) if ivar(:@page) == 3
    return spots
  end

  # @param step [Integer]
  def on_wheel(step)
    press((step < 0) ? Input::UP : Input::DOWN)
  end
end

# @brief Choosing a form on the Forms page (pbChooseForm): wheel or the arrows to browse, click
# to choose.
class PokedexFormMouseAdapter < ScreenAdapter
  # @return [Array<Hash>]
  def hotspots
    spots = []
    up = sprite("uparrow")
    down = sprite("downarrow")
    spots.push({ id: :up, rect: up, click: Input::UP, hold: true }) if up&.visible
    spots.push({ id: :down, rect: down, click: Input::DOWN, hold: true }) if down&.visible
    spots.push({ id: :choose, rect: [0, 0, Graphics.width, Graphics.height], click: Input::USE })
    return spots
  end

  # @param step [Integer]
  def on_wheel(step)
    press((step < 0) ? Input::UP : Input::DOWN)
  end
end

# @brief A brief Pokédex entry (e.g. after catching a Pokémon): click to close.
class PokedexBriefMouseAdapter < ScreenAdapter
  # @return [Array<Hash>]
  def hotspots
    return [{ id: :close, rect: [0, 0, Graphics.width, Graphics.height], click: Input::USE }]
  end
end

ScreenMouse.wrap(PokemonPokedexInfo_Scene, PokedexEntryMouseAdapter, :pbScene)
ScreenMouse.wrap(PokemonPokedexInfo_Scene, PokedexFormMouseAdapter, :pbChooseForm)
ScreenMouse.wrap(PokemonPokedexInfo_Scene, PokedexBriefMouseAdapter, :pbSceneBrief)

#==================================================================
# Pokédex search
#==================================================================
# @brief Pokédex search screens: hover an option to move the cursor to it, click to choose it.
# The search loops keep their cursor in a local variable, so the cursor is steered with arrow
# presses using the option positions below (taken from PokedexSearchSelectionSprite).
# The height/weight sliders stay keyboard-only.
class PokedexSearchMouseAdapter < ScreenAdapter
  # Option rects on the main search screen, by cursor index
  MAIN_RECTS = {
    0 => [252, 52, 184, 44],                                   # Order
    1 => [114, 110, 252, 44], 2 => [114, 162, 252, 44],        # Name, type
    3 => [114, 214, 252, 44], 4 => [114, 266, 252, 44],        # Height, weight
    5 => [382, 110, 124, 44],                                  # Color
    6 => [420, 214, 68, 68],                                   # Shape
    7 => [4, 334, 152, 44], 8 => [180, 334, 152, 44], 9 => [356, 334, 152, 44]   # Reset, start, cancel
  }.freeze
  OK_RECT     = [4, 334, 152, 44].freeze
  CANCEL_RECT = [356, 334, 152, 44].freeze

  # @brief Option rects for the screen being shown, by cursor index.
  # @return [Hash{Integer => Array<Integer>}]
  def option_rects
    cursor = sprite("searchcursor")
    return {} if !cursor || !cursor.visible
    mode = cursor.instance_variable_get(:@mode)
    return MAIN_RECTS if mode == -1
    return {} if [3, 4].include?(mode)   # Height/weight sliders
    xs = cursor.instance_variable_get(:@xstart)
    ys = cursor.instance_variable_get(:@ystart)
    xg = cursor.instance_variable_get(:@xgap)
    yg = cursor.instance_variable_get(:@ygap)
    cols = cursor.instance_variable_get(:@cols)
    return {} if !xs || !cols
    rects = {}
    cursor.cmds.to_i.times do |i|
      rects[i] = [xs + (xg * (i % cols)), ys + (yg * (i / cols)), xg - 4, yg - 4]
    end
    rects[-2] = OK_RECT
    rects[-3] = CANCEL_RECT
    return rects
  end

  # @return [Array<Hash>]
  def hotspots
    cursor = sprite("searchcursor")
    rects = option_rects
    return rects.map do |i, rect|
      { id: i, rect: rect,
        goto: proc do
          from = rects[cursor.index]
          (cursor.index == i || !from) ? nil : spatial_step(from, rect)
        end }
    end
  end
end

ScreenMouse.wrap(PokemonPokedex_Scene, PokedexSearchMouseAdapter, :pbDexSearch, :pbDexSearchCommands)

#==================================================================
# Region Map
#==================================================================
# @brief Region Map / Town Map / Fly map (pbMapScene): the cursor follows the mouse over the map,
# and a click flies there when choosing a destination.
class RegionMapMouseAdapter < ScreenAdapter
  # @brief The map area on screen.
  # @return [Array<Integer>, nil]
  def map_rect
    map = sprite("map")
    return nil if !map || !map.bitmap
    x = (Graphics.width - map.bitmap.width) / 2
    y = (Graphics.height - map.bitmap.height) / 2
    w = (PokemonRegionMap_Scene::RIGHT - PokemonRegionMap_Scene::LEFT + 1) * PokemonRegionMap_Scene::SQUARE_WIDTH
    h = (PokemonRegionMap_Scene::BOTTOM - PokemonRegionMap_Scene::TOP + 1) * PokemonRegionMap_Scene::SQUARE_HEIGHT
    return [x, y, w, h]
  end

  # @return [Array<Hash>]
  def hotspots
    rect = map_rect
    return [] if !rect
    return [{ id: :map, rect: rect, hover: proc { follow(rect) }, click: Input::USE }]
  end

  # @brief Moves the map cursor to the square under the mouse, if the cursor isn't mid-move.
  # @param rect [Array<Integer>] The map area.
  def follow(rect)
    pos = MouseInput.position
    cursor = sprite("cursor")
    return if !pos || !cursor
    map_x = ivar(:@map_x)
    map_y = ivar(:@map_y)
    # Only move a cursor that is at rest; the loop is still sliding it otherwise
    return if cursor.x != @scene.point_x_to_screen_x(map_x) || cursor.y != @scene.point_y_to_screen_y(map_y)
    sq_w = PokemonRegionMap_Scene::SQUARE_WIDTH
    sq_h = PokemonRegionMap_Scene::SQUARE_HEIGHT
    x = ((pos[0] - rect[0]) / sq_w).clamp(PokemonRegionMap_Scene::LEFT, PokemonRegionMap_Scene::RIGHT)
    y = ((pos[1] - rect[1]) / sq_h).clamp(PokemonRegionMap_Scene::TOP, PokemonRegionMap_Scene::BOTTOM)
    return if x == map_x && y == map_y
    @scene.instance_variable_set(:@map_x, x)
    @scene.instance_variable_set(:@map_y, y)
    cursor.x = @scene.point_x_to_screen_x(x)
    cursor.y = @scene.point_y_to_screen_y(y)
  end
end

ScreenMouse.wrap(PokemonRegionMap_Scene, RegionMapMouseAdapter, :pbMapScene)

#==================================================================
# Trainer Card
#==================================================================
# @brief Trainer Card: a left click closes it too.
class TrainerCardMouseAdapter < ScreenAdapter
  # @return [Array<Hash>]
  def hotspots
    return [{ id: :close, rect: [0, 0, Graphics.width, Graphics.height], click: Input::BACK }]
  end
end

ScreenMouse.wrap(PokemonTrainerCard_Scene, TrainerCardMouseAdapter, :pbTrainerCard)

#==================================================================
# Move Relearner
#==================================================================
# @brief Move Relearner (pbChooseMove): hover a move to highlight it, click to learn it, wheel or
# the drawn up/down buttons to scroll. Its list window is hidden, so the rows are drawn here.
class MoveRelearnerMouseAdapter < ScreenAdapter
  ROW_Y      = 78
  ROW_HEIGHT = 64
  ROW_WIDTH  = 258
  DOWN_BUTTON = [48, 350, 76, 32].freeze
  UP_BUTTON   = [134, 350, 76, 32].freeze

  # @return [Array<Hash>]
  def hotspots
    cmds = sprite("commands")
    return [] if !cmds
    spots = []
    MoveRelearner_Scene::VISIBLEMOVES.times do |i|
      index = MenuWindows.shown_top_row(cmds) + i
      next if index >= cmds.itemCount
      spots.push({ id: [:row, i], rect: [0, ROW_Y + (i * ROW_HEIGHT), ROW_WIDTH, ROW_HEIGHT],
                   hover: proc { select(index) }, click: Input::USE })
    end
    spots.push({ id: :down, rect: DOWN_BUTTON, click: Input::DOWN, hold: true }) if cmds.index < cmds.itemCount - 1
    spots.push({ id: :up, rect: UP_BUTTON, click: Input::UP, hold: true }) if cmds.index > 0
    return spots
  end

  # @brief Highlights a move without scrolling the list.
  # @param index [Integer]
  def select(index)
    cmds = sprite("commands")
    return if !cmds || cmds.index == index
    cmds.instance_variable_set(:@mouse_pin, MenuWindows.shown_top_row(cmds))
    cmds.index = index
    pbPlayCursorSE
  end

  # @param step [Integer]
  def on_wheel(step)
    press((step < 0) ? Input::UP : Input::DOWN)
  end
end

ScreenMouse.wrap(MoveRelearner_Scene, MoveRelearnerMouseAdapter, :pbChooseMove)

#==================================================================
# Name entry grid
#==================================================================
# @brief The on-screen keyboard (PokemonEntryScene2#pbEntry): hover a character, tab, Back or OK
# to move the cursor there, click to press it. A right click is that screen's Back, which deletes
# a character.
class TextEntryMouseAdapter < ScreenAdapter
  # @return [Array<Hash>]
  def hotspots
    spots = []
    columns = PokemonEntryScene2::ROWS     # Characters per row
    rows = PokemonEntryScene2::COLUMNS     # Rows of characters
    (columns * rows).times do |n|
      spots.push({ id: n, rect: [52 + (32 * (n % columns)), 180 + (38 * (n / columns)), 32, 38],
                   hover: proc { select(n) }, click: Input::USE })
    end
    4.times do |k|
      pos = PokemonEntryScene2::MODE1 + k
      spots.push({ id: pos, rect: [44 + (62 * k), 120, 60, 44], hover: proc { select(pos) }, click: Input::USE })
    end
    spots.push({ id: PokemonEntryScene2::BACK, rect: [314, 120, 78, 44],
                 hover: proc { select(PokemonEntryScene2::BACK) }, click: Input::USE })
    spots.push({ id: PokemonEntryScene2::OK, rect: [394, 120, 78, 44],
                 hover: proc { select(PokemonEntryScene2::OK) }, click: Input::USE })
    return spots
  end

  # @brief Moves the cursor as the arrow keys do.
  # @param pos [Integer]
  def select(pos)
    return if ivar(:@cursorpos) == pos
    @scene.instance_variable_set(:@cursorpos, pos)
    sprite("cursor")&.setCursorPos(pos)
    pbPlayCursorSE
  end

  # @brief The name entry cursor isn't a Sprite, so it is looked up without the disposed check.
  # @param key [String]
  # @return [Object, nil]
  def sprite(key)
    return ivar(:@sprites)&.[](key)
  end
end

ScreenMouse.wrap(PokemonEntryScene2, TextEntryMouseAdapter, :pbEntry)
