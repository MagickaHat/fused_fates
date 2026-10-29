#================================================================================================
# Pokémon Fused Fates Utilities/Mouse - 007_MenuScreens.rb
#================================================================================================
# Mouse support for the sprite-drawn menu screens: Party, Summary, PC boxes, Bag pockets,
# Ready menu, Pokégear and the load screen. Everything here only presses keys or changes the
# same values the screens' own key handling changes, so the keyboard keeps working as before.

#==================================================================
# Party screen
#==================================================================
# @brief Party screen (PokemonParty_Scene#pbChoosePokemon): hover a Pokémon or Cancel/Confirm to
# select it, click to choose it.
class PartyMouseAdapter < ScreenAdapter
  # @return [Array<Hash>]
  def hotspots
    party = ivar(:@party) || []
    return (0...button_count).filter_map do |i|
      spr = sprite("pokemon#{i}")
      next nil if !spr || !spr.visible
      next nil if i < Settings::MAX_PARTY_SIZE && !party[i]
      { id: i, rect: panel_rect(spr, i), hover: proc { select(i) }, click: Input::USE }
    end
  end

  # @brief Number of selectable sprites (party slots plus Cancel, or Confirm and Cancel).
  # @return [Integer]
  def button_count
    return Settings::MAX_PARTY_SIZE + (ivar(:@multiselect) ? 2 : 1)
  end

  # @brief On-screen rect of a party panel or button. Their images live on inner sprites.
  # @return [Array<Integer>]
  def panel_rect(spr, i)
    return [spr.x, spr.y, Graphics.width / 2, 96] if i < Settings::MAX_PARTY_SIZE
    bg = spr.instance_variable_get(:@bgsprite)
    bmp = bg&.bitmap
    return [spr.x, spr.y, bmp.width, bmp.height] if bmp && !bmp.disposed?
    return [spr.x, spr.y, 112, 48]
  end

  # @brief Selects a party slot or button the same way the arrow keys do.
  # @param i [Integer]
  def select(i)
    return if ivar(:@activecmd) == i
    @scene.instance_variable_set(:@activecmd, i)
    button_count.times { |j| sprite("pokemon#{j}")&.selected = (j == i) }
    pbPlayCursorSE
  end
end

ScreenMouse.wrap(PokemonParty_Scene, PartyMouseAdapter, :pbChoosePokemon)

#==================================================================
# Summary screen
#==================================================================
# @brief Summary screen main view. Click a page tab to go to it, wheel over the tabs to change
# page, wheel elsewhere to change Pokémon, click the Pokémon to hear its cry, and click the info
# panel to open it (moves, ribbons or options) as Use does.
# Attached on scene start rather than wrapping pbScene, which Super Contests replaces.
class SummaryMouseAdapter < ScreenAdapter
  TAB_X     = 228   # Left edge of the first page tab in the Summary backgrounds
  TAB_WIDTH = 56
  TAB_COUNT = 5     # Tabs drawn in the art
  HEADER_HEIGHT = 56
  PANEL_RECT = [212, 58, 300, 316].freeze   # The page's info panel

  # @return [Symbol]
  def wheel_kind
    return :page
  end

  # @return [Array<Hash>]
  def hotspots
    spots = []
    pokemon = ivar(:@pokemon)
    return spots if !pokemon
    if !pokemon.egg?
      if page_count == TAB_COUNT
        TAB_COUNT.times do |i|
          spots.push({ id: [:tab, i], rect: [TAB_X + (i * TAB_WIDTH), 0, TAB_WIDTH, HEADER_HEIGHT],
                       goto: proc { step_toward(ivar(:@page), i + 1, Input::LEFT, Input::RIGHT) },
                       hover_nav: false, click: nil, wheel: proc { |s| page_step(s) }, page: true })
        end
      else
        # More pages than tabs in the art (e.g. Super Contests' Condition page): click the left
        # or right part of the tab strip to step one page
        strip_w = TAB_COUNT * TAB_WIDTH
        spots.push({ id: :tabs_left, rect: [TAB_X, 0, strip_w / 2, HEADER_HEIGHT],
                     click: Input::LEFT, wheel: proc { |s| page_step(s) }, page: true })
        spots.push({ id: :tabs_right, rect: [TAB_X + (strip_w / 2), 0, strip_w - (strip_w / 2), HEADER_HEIGHT],
                     click: Input::RIGHT, wheel: proc { |s| page_step(s) }, page: true })
      end
    end
    pkmn_sprite = sprite("pokemon")
    spots.push({ id: :pokemon, rect: pkmn_sprite, click: Input::ACTION }) if pkmn_sprite&.bitmap
    spots.push({ id: :panel, rect: PANEL_RECT, click: Input::USE })
    return spots
  end

  # @brief Number of Summary pages (Super Contests may add one).
  # @return [Integer]
  def page_count
    return @scene.send(:summary_page_count) if @scene.respond_to?(:summary_page_count, true)
    return TAB_COUNT
  end

  # @brief Steps one page with the wheel.
  # @param step [Integer]
  def page_step(step)
    press((step < 0) ? Input::LEFT : Input::RIGHT)
  end

  # @brief Wheel away from the tabs: previous/next Pokémon.
  # @param step [Integer]
  def on_wheel(step)
    press((step < 0) ? Input::UP : Input::DOWN)
  end
end

# @brief Summary move list (pbMoveSelection): hover a move to highlight it, click to pick it up
# or swap it, wheel to move up/down.
class SummaryMovesMouseAdapter < ScreenAdapter
  ROW_X      = 240
  ROW_Y      = 92
  ROW_HEIGHT = 64

  # @brief Rows that can be selected.
  # @return [Array<Integer>]
  def rows
    pokemon = ivar(:@pokemon)
    return pokemon ? (0...pokemon.numMoves).to_a : []
  end

  # @brief On-screen rect of a move row.
  # @param i [Integer]
  # @return [Array<Integer>]
  def row_rect(i)
    sel = sprite("movesel")
    width = sel&.bitmap ? sel.bitmap.width : 272
    return [ROW_X, ROW_Y + (i * ROW_HEIGHT), width, ROW_HEIGHT]
  end

  # @brief The highlighted move row.
  # @return [Integer, nil]
  def current
    return sprite("movesel")&.index
  end

  # @return [Array<Hash>]
  def hotspots
    return rows.map do |i|
      { id: i, rect: row_rect(i), goto: proc { step_toward(current, i, Input::UP, Input::DOWN) } }
    end
  end

  # @param step [Integer]
  def on_wheel(step)
    press((step < 0) ? Input::UP : Input::DOWN)
  end
end

# @brief Choosing a move to forget (pbChooseMoveToForget), including the new move in fifth place.
class SummaryForgetMouseAdapter < SummaryMovesMouseAdapter
  # @return [Array<Integer>]
  def rows
    list = super
    list.push(Pokemon::MAX_MOVES) if fifth_move?
    return list
  end

  # @brief Whether the new move is shown as a fifth row.
  # @return [Boolean]
  def fifth_move?
    return sprite("movesel")&.instance_variable_get(:@fifthmove) ? true : false
  end

  # @param i [Integer]
  # @return [Array<Integer>]
  def row_rect(i)
    rect = super
    if fifth_move?
      rect[1] -= 76
      rect[1] += 20 if i == Pokemon::MAX_MOVES   # Matches MoveSelectionSprite's gap
    end
    return rect
  end
end

# @brief Summary ribbon grid (pbRibbonSelection): hover a ribbon to highlight it, click to pick it
# up or swap it, wheel or the arrows to scroll rows.
class SummaryRibbonsMouseAdapter < ScreenAdapter
  COLUMNS = 4
  VISIBLE_ROWS = 3

  # @brief Total rows in the ribbon grid (as pbRibbonSelection counts them).
  # @return [Integer]
  def total_rows
    count = ivar(:@pokemon)&.ribbons&.length || 0
    return [((count + 3) / 4).floor, VISIBLE_ROWS].max
  end

  # @brief Absolute index of the highlighted ribbon.
  # @return [Integer, nil]
  def current
    sel = sprite("ribbonsel")
    return nil if !sel
    return (ivar(:@ribbonOffset).to_i * COLUMNS) + sel.index
  end

  # @brief Where a key moves the ribbon cursor (same rules as pbRibbonSelection).
  # @return [Integer]
  def ribbon_step(key, sel)
    size = total_rows * COLUMNS
    case key
    when Input::UP    then sel -= COLUMNS; sel += size if sel < 0
    when Input::DOWN  then sel += COLUMNS; sel -= size if sel >= size
    when Input::LEFT  then sel -= 1; sel += COLUMNS if sel % COLUMNS == COLUMNS - 1
    when Input::RIGHT then sel += 1; sel -= COLUMNS if sel % COLUMNS == 0
    end
    return sel
  end

  # @return [Array<Hash>]
  def hotspots
    offset = ivar(:@ribbonOffset).to_i
    keys = [Input::UP, Input::DOWN, Input::LEFT, Input::RIGHT]
    spots = (COLUMNS * VISIBLE_ROWS).times.map do |c|
      target = (offset * COLUMNS) + c
      { id: [:ribbon, target], rect: [230 + (68 * (c % COLUMNS)), 78 + (68 * (c / COLUMNS)), 64, 64],
        goto: proc { navigate(current, target, keys) { |k, s| ribbon_step(k, s) } } }
    end
    up = sprite("uparrow")
    down = sprite("downarrow")
    spots.push({ id: :up, rect: up, click: Input::UP, hold: true }) if up&.visible
    spots.push({ id: :down, rect: down, click: Input::DOWN, hold: true }) if down&.visible
    return spots
  end

  # @param step [Integer]
  def on_wheel(step)
    press((step < 0) ? Input::UP : Input::DOWN)
  end
end

MouseUI.attach_scene(PokemonSummary_Scene, SummaryMouseAdapter,
                     start: [:pbStartScene, :pbStartForgetScene], finish: :pbEndScene)
ScreenMouse.wrap(PokemonSummary_Scene, SummaryMovesMouseAdapter, :pbMoveSelection)
ScreenMouse.wrap(PokemonSummary_Scene, SummaryRibbonsMouseAdapter, :pbRibbonSelection)
ScreenMouse.wrap(PokemonSummary_Scene, SummaryForgetMouseAdapter, :pbChooseMoveToForget)
# The markings editor has no mouse hotspots yet; this keeps the main view's clicks out of it
ScreenMouse.wrap(PokemonSummary_Scene, ScreenAdapter, :pbMarking)

#==================================================================
# PC boxes
#==================================================================
class PokemonStorageScene
  alias __mouse_pbSetArrow pbSetArrow unless method_defined?(:__mouse_pbSetArrow)
  alias __mouse_pbPartySetArrow pbPartySetArrow unless method_defined?(:__mouse_pbPartySetArrow)

  # @return [Integer, nil] The box-mode selection the arrow was last moved to (for the mouse).
  attr_reader :mouse_box_selection
  # @return [Integer, nil] The party-mode selection the arrow was last moved to (for the mouse).
  attr_reader :mouse_party_selection

  # @brief Moves the arrow as usual and remembers the selection, which the box loop keeps in a
  # local variable.
  def pbSetArrow(arrow, selection)
    @mouse_box_selection = selection
    return __mouse_pbSetArrow(arrow, selection)
  end

  # @brief Moves the party arrow as usual and remembers the selection.
  def pbPartySetArrow(arrow, selection)
    @mouse_party_selection = selection
    return __mouse_pbPartySetArrow(arrow, selection)
  end
end

# @brief PC box view (pbSelectBoxInternal): hover a slot, the box name or the Party/Close buttons
# to move the arrow there, click to choose. Click the ends of the box name, or use the wheel over
# the box, to change box.
class StorageBoxMouseAdapter < ScreenAdapter
  PARTY_BUTTON = [186, 320, 168, 44].freeze   # From overlay_main
  CLOSE_BUTTON = [386, 320, 120, 44].freeze
  NAME_HEIGHT  = 30
  NAME_END     = 60   # Width of each clickable end of the box name bar

  # @return [Symbol]
  def wheel_kind
    return :page
  end

  # @brief Where a key moves the selection, ignoring the "switch box" results.
  # @return [Integer, nil]
  def box_step(key, sel)
    ret = @scene.pbChangeSelection(key, sel)
    return [-4, -5].include?(ret) ? nil : ret
  end

  # @brief A :goto proc toward a selection. The path never passes through the box name or the
  # Party/Close buttons on the way to a slot, so the arrow moves the way a player would move it.
  # @return [Proc]
  def goto_selection(target)
    keys = [Input::UP, Input::DOWN, Input::LEFT, Input::RIGHT]
    return proc do
      navigate(@scene.mouse_box_selection, target, keys) do |k, s|
        nxt = box_step(k, s)
        (nxt && nxt < 0 && nxt != target) ? nil : nxt
      end
    end
  end

  # @return [Array<Hash>]
  def hotspots
    box = sprite("box")
    return [] if !box
    spots = []
    PokemonBox::BOX_SIZE.times do |i|
      k = i % PokemonBox::BOX_WIDTH
      j = i / PokemonBox::BOX_WIDTH
      spots.push({ id: i, rect: [box.x + 10 + (48 * k), box.y + 30 + (48 * j), 48, 48],
                   goto: goto_selection(i), wheel: proc { |s| box_step_wheel(s) }, page: true })
    end
    width = box.bitmap ? box.bitmap.width : 324
    spots.push({ id: :prev_box, rect: [box.x, box.y, NAME_END, NAME_HEIGHT], click: Input::JUMPUP,
                 wheel: proc { |s| box_step_wheel(s) }, page: true })
    spots.push({ id: :next_box, rect: [box.x + width - NAME_END, box.y, NAME_END, NAME_HEIGHT],
                 click: Input::JUMPDOWN, wheel: proc { |s| box_step_wheel(s) }, page: true })
    spots.push({ id: -1, rect: [box.x + NAME_END, box.y, width - (NAME_END * 2), NAME_HEIGHT],
                 goto: goto_selection(-1), wheel: proc { |s| box_step_wheel(s) }, page: true })
    spots.push({ id: -2, rect: PARTY_BUTTON, goto: goto_selection(-2) })
    spots.push({ id: -3, rect: CLOSE_BUTTON, goto: goto_selection(-3) })
    return spots
  end

  # @brief Wheel over the box: previous/next box.
  # @param step [Integer]
  def box_step_wheel(step)
    press((step < 0) ? Input::JUMPUP : Input::JUMPDOWN)
  end
end

# @brief PC party panel (pbSelectPartyInternal): hover a Pokémon or Back to move the arrow there,
# click to choose.
class StoragePartyMouseAdapter < ScreenAdapter
  BACK_BUTTON = [18, 228, 136, 58].freeze   # Inside the party panel (overlay_party)

  # @return [Array<Hash>]
  def hotspots
    panel = sprite("boxparty")
    return [] if !panel || !panel.visible
    keys = [Input::UP, Input::DOWN, Input::LEFT, Input::RIGHT]
    targets = (0..Settings::MAX_PARTY_SIZE).to_a
    return targets.map do |i|
      rect = if i == Settings::MAX_PARTY_SIZE
               [panel.x + BACK_BUTTON[0], panel.y + BACK_BUTTON[1], BACK_BUTTON[2], BACK_BUTTON[3]]
             else
               [panel.x + 18 + (72 * (i % 2)), panel.y + 2 + (16 * (i % 2)) + (64 * (i / 2)), 64, 64]
             end
      { id: i, rect: rect,
        goto: proc { navigate(@scene.mouse_party_selection, i, keys) { |k, s| @scene.pbPartyChangeSelection(k, s) } } }
    end
  end
end

ScreenMouse.wrap(PokemonStorageScene, StorageBoxMouseAdapter, :pbSelectBoxInternal)
ScreenMouse.wrap(PokemonStorageScene, StoragePartyMouseAdapter, :pbSelectPartyInternal)

#==================================================================
# Bag pockets
#==================================================================
# @brief Bag (pbChooseItem): click or hold the pocket arrows, click a pocket icon, or use the
# wheel over the pocket icons to change pocket. The item list is a normal list window.
class BagMouseAdapter < ScreenAdapter
  POCKET_X     = 2    # First pocket icon in the pocket strip
  POCKET_WIDTH = 22

  # @return [Array<Hash>]
  def hotspots
    list = sprite("itemlist")
    return [] if !list || list.sorting
    spots = []
    left = sprite("leftarrow")
    right = sprite("rightarrow")
    wheel = proc { |s| press((s < 0) ? Input::LEFT : Input::RIGHT) }
    spots.push({ id: :left, rect: left, click: Input::LEFT, hold: true, wheel: wheel, page: true }) if left&.visible
    spots.push({ id: :right, rect: right, click: Input::RIGHT, hold: true, wheel: wheel, page: true }) if right&.visible
    strip = sprite("pocketicon")
    bag = ivar(:@bag)
    if strip && bag
      (1...bag.pockets.length).each do |p|
        spots.push({ id: [:pocket, p], rect: [strip.x + POCKET_X + ((p - 1) * POCKET_WIDTH), strip.y, POCKET_WIDTH, 32],
                     goto: proc { step_toward(list.pocket, p, Input::LEFT, Input::RIGHT) },
                     hover_nav: false, click: nil, wheel: wheel, page: true })
      end
    end
    return spots
  end
end

ScreenMouse.wrap(PokemonBag_Scene, BagMouseAdapter, :pbChooseItem)

#==================================================================
# Ready menu
#==================================================================
# @brief Ready menu (registered moves/items): hover a button to highlight it, click to use it.
# Clicking a button on the other side switches side first.
class ReadyMenuMouseAdapter < ScreenAdapter
  # @return [Array<Hash>]
  def hotspots
    index = ivar(:@index)
    return [] if !index
    spots = []
    [["movebutton", 0, Input::LEFT], ["itembutton", 1, Input::RIGHT]].each do |name, side, key|
      i = 0
      while (btn = sprite("#{name}#{i}"))
        n = i
        spots.push({ id: [side, n], rect: btn, hover: proc { select(n) if index[2] == side },
                     goto: proc { (index[2] != side) ? key : (select(n) || nil) }, hover_nav: false }) if btn.visible
        i += 1
      end
    end
    return spots
  end

  # @brief Highlights a button on the current side.
  # @param i [Integer]
  # @return [nil]
  def select(i)
    cmd = sprite("cmdwindow")
    return nil if !cmd || cmd.index == i
    cmd.index = i
    pbPlayCursorSE
    return nil
  end

  # @param step [Integer]
  def on_wheel(step)
    press((step < 0) ? Input::UP : Input::DOWN)
  end
end

ScreenMouse.wrap(PokemonReadyMenu_Scene, ReadyMenuMouseAdapter, :pbShowCommands)

#==================================================================
# Pokégear
#==================================================================
# @brief Pokégear menu: hover a button to highlight it, click to open it.
class PokegearMouseAdapter < ScreenAdapter
  # @return [Array<Hash>]
  def hotspots
    spots = []
    i = 0
    while (btn = sprite("button#{i}"))
      n = i
      spots.push({ id: n, rect: part_rect(btn, 2), hover: proc { select(n) }, click: Input::USE })
      i += 1
    end
    return spots
  end

  # @param i [Integer]
  def select(i)
    return if ivar(:@index) == i
    @scene.instance_variable_set(:@index, i)
    pbPlayCursorSE
  end

  # @param step [Integer]
  def on_wheel(step)
    press((step < 0) ? Input::UP : Input::DOWN)
  end
end

ScreenMouse.wrap(PokemonPokegear_Scene, PokegearMouseAdapter, :pbScene)

#==================================================================
# Load screen
#==================================================================
# @brief Load screen (Continue / New Game / Options...): hover a panel to highlight it, click
# to choose it, wheel to move up/down.
class LoadMouseAdapter < ScreenAdapter
  CONTINUE_HEIGHT = 222
  PANEL_HEIGHT    = 46

  # @return [Array<Hash>]
  def hotspots
    spots = []
    i = 0
    while (panel = sprite("panel#{i}"))
      n = i
      height = panel.instance_variable_get(:@isContinue) ? CONTINUE_HEIGHT : PANEL_HEIGHT
      width = panel.bitmap ? panel.bitmap.width : 416
      spots.push({ id: n, rect: [panel.x, panel.y, width, height], hover: proc { select(n) }, click: Input::USE })
      i += 1
    end
    return spots
  end

  # @param i [Integer]
  def select(i)
    cmd = sprite("cmdwindow")
    return if !cmd || cmd.index == i
    cmd.index = i
    pbPlayCursorSE
  end

  # @param step [Integer]
  def on_wheel(step)
    press((step < 0) ? Input::UP : Input::DOWN)
  end
end

ScreenMouse.wrap(PokemonLoad_Scene, LoadMouseAdapter, :pbChoose)
