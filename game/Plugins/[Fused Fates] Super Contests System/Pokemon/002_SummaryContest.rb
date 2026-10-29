#================================================================================================
# Pokémon Fused Fates Super Contests System/Pokemon - 002_SummaryContest.rb
#================================================================================================
# Adds contest information to the summary screen:
#   - Page 6, CONDITION: the condition pentagon, each condition's value, sheen
#     and the flavors the Pokémon's nature likes and dislikes.
#   - The MOVES page switches to CONTEST MOVES with
#     ContestSettings::CONTEST_MOVES_TOGGLE, showing each move's condition,
#     appeal, contest effect and contest description.
# Each can be hidden behind a game switch: see CONDITION_PAGE_SWITCH and
# CONTEST_MOVES_SWITCH in ContestSettings.

#==================================================================
# module ContestUI
#==================================================================
# @brief Drawing helpers shared by contest screens.
module ContestUI
  module_function

  # @brief Draws a condition's 64x28 label: the cell from
  # ContestSettings::CONDITION_ICONS if that graphic exists, otherwise a
  # colored box with the condition's name.
  # @param bitmap [Bitmap]
  # @param condition [Symbol, GameData::ContestCondition]
  # @param x [Integer]
  # @param y [Integer]
  def draw_condition_label(bitmap, condition, x, y)
    data = GameData::ContestCondition.get(condition)
    if pbResolveBitmap(ContestSettings::CONDITION_ICONS)
      pbDrawImagePositions(bitmap, [[ContestSettings::CONDITION_ICONS, x, y, 0, data.icon_position * 28, 64, 28]])
      return
    end
    bitmap.fill_rect(x + 1, y, 62, 28, data.shadow_color)
    bitmap.fill_rect(x, y + 1, 64, 26, data.shadow_color)
    bitmap.fill_rect(x + 2, y + 2, 60, 24, data.color)
    pbDrawTextPositions(bitmap, [[data.name, x + 32, y + 6, :center,
                                  Color.new(248, 248, 248), data.shadow_color]])
  end

  # @brief Fills a polygon, one scanline at a time.
  # @param bitmap [Bitmap]
  # @param points [Array<Array<Numeric>>] [x, y] corners, in order.
  # @param color [Color]
  def fill_polygon(bitmap, points, color)
    return if points.length < 3
    min_y = points.map { |p| p[1] }.min.ceil
    max_y = points.map { |p| p[1] }.max.floor
    (min_y..max_y).each do |y|
      xs = []
      points.each_with_index do |a, i|
        b = points[(i + 1) % points.length]
        next if a[1] == b[1]
        lo, hi = (a[1] < b[1]) ? [a, b] : [b, a]
        next if y < lo[1] || y >= hi[1]
        xs.push(lo[0] + ((y - lo[1]) * (hi[0] - lo[0]) / (hi[1] - lo[1]).to_f))
      end
      xs.sort!
      xs.each_slice(2) do |x1, x2|
        next if !x2
        bitmap.fill_rect(x1.round, y, (x2 - x1).round + 1, 1, color)
      end
    end
  end

  # @brief Draws a straight line.
  # @param bitmap [Bitmap]
  # @param from [Array<Numeric>] [x, y]
  # @param to [Array<Numeric>] [x, y]
  # @param color [Color]
  # @param thickness [Integer]
  def draw_line(bitmap, from, to, color, thickness = 2)
    steps = [(to[0] - from[0]).abs, (to[1] - from[1]).abs].max.ceil
    steps = 1 if steps < 1
    (0..steps).each do |i|
      x = from[0] + ((to[0] - from[0]) * i / steps.to_f)
      y = from[1] + ((to[1] - from[1]) * i / steps.to_f)
      bitmap.fill_rect((x - (thickness / 2)).round, (y - (thickness / 2)).round, thickness, thickness, color)
    end
  end

  # @brief Corners of a regular pentagon, the first one pointing up.
  # @param cx [Numeric] Centre x.
  # @param cy [Numeric] Centre y.
  # @param radii [Array<Numeric>] Distance of each corner from the centre.
  # @return [Array<Array<Float>>]
  def pentagon(cx, cy, radii)
    return radii.each_with_index.map do |r, i|
      angle = (-90 + (72 * i)) * Math::PI / 180
      [cx + (r * Math.cos(angle)), cy + (r * Math.sin(angle))]
    end
  end
end

#==================================================================
# class PokemonSummary_Scene
#==================================================================
class PokemonSummary_Scene
  # @brief Index of the Condition page.
  CONDITION_PAGE = 6

  alias_method :__contests_drawPageFour, :drawPageFour unless method_defined?(:__contests_drawPageFour)
  alias_method :__contests_drawPageFourSelecting, :drawPageFourSelecting unless method_defined?(:__contests_drawPageFourSelecting)
  alias_method :__contests_drawSelectedMove, :drawSelectedMove unless method_defined?(:__contests_drawSelectedMove)

  # @brief Whether the Condition page can be viewed (its game switch is on).
  # @return [Boolean]
  def condition_page_enabled?
    return ContestSettings.switch_on?(ContestSettings::CONDITION_PAGE_SWITCH)
  end

  # @brief Whether the Moves page can switch to contest information (its
  # game switch is on).
  # @return [Boolean]
  def contest_moves_enabled?
    return ContestSettings.switch_on?(ContestSettings::CONTEST_MOVES_SWITCH)
  end

  # @brief Number of summary pages: 6 with the Condition page, 5 without.
  # @return [Integer]
  def summary_page_count
    return condition_page_enabled? ? CONDITION_PAGE : CONDITION_PAGE - 1
  end

  # @brief Whether the Moves page shows contest information. Always false
  # while contest moves are disabled.
  # @return [Boolean]
  def contest_moves?
    return contest_moves_enabled? && (@contest_moves || false)
  end

  # @brief Background of the Condition page.
  # @return [String]
  def condition_page_bg
    return ContestSettings::CONDITION_PAGE_BG if pbResolveBitmap(ContestSettings::CONDITION_PAGE_BG)
    return ContestSettings::CONDITION_PAGE_FALLBACK_BG
  end

  # @brief Draws a page. Replaces the base method so it knows the Condition
  # page's title and background (the base one only knows pages 1 to 5).
  # @param page [Integer]
  def drawPage(page)
    if @pokemon.egg?
      drawPageOneEgg
      return
    end
    @sprites["pokemon"].setPokemonBitmap(@pokemon)
    @sprites["pokeicon"].pokemon = @pokemon
    @sprites["itemicon"].item = @pokemon.item_id
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    base   = Color.new(248, 248, 248)
    shadow = Color.new(104, 104, 104)
    # Set background image
    if page == CONDITION_PAGE
      @sprites["background"].setBitmap(condition_page_bg)
    else
      @sprites["background"].setBitmap("Graphics/UI/Summary/bg_#{page}")
    end
    imagepos = []
    # Show the Poké Ball containing the Pokémon
    ballimage = sprintf("Graphics/UI/Summary/icon_ball_%s", @pokemon.poke_ball)
    imagepos.push([ballimage, 14, 60])
    # Show status/fainted/Pokérus infected icon
    status = -1
    if @pokemon.fainted?
      status = GameData::Status.count - 1
    elsif @pokemon.status != :NONE
      status = GameData::Status.get(@pokemon.status).icon_position
    elsif @pokemon.pokerusStage == 1
      status = GameData::Status.count
    end
    if status >= 0
      imagepos.push([_INTL("Graphics/UI/statuses"), 124, 100, 0, 16 * status, 44, 16])
    end
    # Show Pokérus cured icon
    if @pokemon.pokerusStage == 2
      imagepos.push(["Graphics/UI/Summary/icon_pokerus", 176, 100])
    end
    # Show shininess star
    imagepos.push(["Graphics/UI/shiny", 2, 134]) if @pokemon.shiny?
    # Draw all images
    pbDrawImagePositions(overlay, imagepos)
    # Write various bits of text
    pagename = [_INTL("INFO"),
                _INTL("TRAINER MEMO"),
                _INTL("SKILLS"),
                contest_moves? ? _INTL("CONTEST MOVES") : _INTL("MOVES"),
                _INTL("RIBBONS"),
                _INTL("CONDITION")][page - 1]
    textpos = [
      [pagename, 26, 22, :left, base, shadow],
      [@pokemon.name, 46, 68, :left, base, shadow],
      [@pokemon.level.to_s, 46, 98, :left, Color.new(64, 64, 64), Color.new(176, 176, 176)],
      [_INTL("Item"), 66, 324, :left, base, shadow]
    ]
    # Write the held item's name
    if @pokemon.hasItem?
      textpos.push([@pokemon.item.name, 16, 358, :left, Color.new(64, 64, 64), Color.new(176, 176, 176)])
    else
      textpos.push([_INTL("None"), 16, 358, :left, Color.new(192, 200, 208), Color.new(208, 216, 224)])
    end
    # Write the gender symbol
    if @pokemon.male?
      textpos.push([_INTL("♂"), 178, 68, :left, Color.new(24, 112, 216), Color.new(136, 168, 208)])
    elsif @pokemon.female?
      textpos.push([_INTL("♀"), 178, 68, :left, Color.new(248, 56, 32), Color.new(224, 152, 144)])
    end
    # Draw all text
    pbDrawTextPositions(overlay, textpos)
    # Draw the Pokémon's markings
    drawMarkings(overlay, 84, 292)
    # Draw page-specific information
    case page
    when 1 then drawPageOne
    when 2 then drawPageTwo
    when 3 then drawPageThree
    when 4 then drawPageFour
    when 5 then drawPageFive
    when 6 then drawPageSix
    end
  end

  # @brief Draws the Condition page: the condition pentagon, sheen and the
  # nature's flavor preferences.
  def drawPageSix
    overlay = @sprites["overlay"].bitmap
    @sprites["pokemon"].visible  = true
    @sprites["pokeicon"].visible = false
    @sprites["itemicon"].visible = true
    white  = Color.new(248, 248, 248)
    shadow = Color.new(104, 104, 104)
    dark   = Color.new(64, 64, 64)
    light  = Color.new(176, 176, 176)
    cx, cy = ContestSettings::PENTAGON_CENTER
    radius = ContestSettings::PENTAGON_RADIUS
    conditions = GameData::ContestCondition.keys
    # Pentagon backing, guide lines and the Pokémon's shape
    outer = ContestUI.pentagon(cx, cy, [radius] * conditions.length)
    ContestUI.fill_polygon(overlay, outer, Color.new(248, 240, 216))
    ContestUI.fill_polygon(overlay, ContestUI.pentagon(cx, cy, [radius / 2] * conditions.length), Color.new(240, 224, 184))
    radii = conditions.map do |c|
      radius * @pokemon.condition(c) / ContestSettings::MAX_CONDITION.to_f
    end
    shape = ContestUI.pentagon(cx, cy, radii)
    ContestUI.fill_polygon(overlay, shape, Color.new(240, 104, 136)) if radii.any? { |r| r >= 1 }
    outer.each_with_index do |corner, i|
      ContestUI.draw_line(overlay, [cx, cy], corner, Color.new(208, 176, 120), 1)
      ContestUI.draw_line(overlay, corner, outer[(i + 1) % outer.length], Color.new(168, 120, 32), 2)
    end
    # Condition names and values around the pentagon
    textpos = []
    ContestUI.pentagon(cx, cy, [radius + 26] * conditions.length).each_with_index do |pos, i|
      data = GameData::ContestCondition.get(conditions[i])
      x = pos[0].round
      y = pos[1].round - 22
      y -= 8 if i == 0
      textpos.push([data.name, x, y, :center, data.color, data.shadow_color])
      textpos.push([@pokemon.condition(data.id).to_s, x, y + 22, :center, white, shadow])
    end
    # Flavor preferences
    liked    = @pokemon.liked_flavor
    disliked = @pokemon.disliked_flavor
    if liked && disliked
      textpos.push([_INTL("Likes {1}, dislikes {2}", liked.name, disliked.name), cx, 300, :center, white, shadow])
    else
      textpos.push([_INTL("Likes every flavor"), cx, 300, :center, white, shadow])
    end
    # Sheen
    textpos.push([_INTL("Sheen"), 228, 338, :left, dark, light])
    textpos.push([@pokemon.contest_sheen.to_s, 500, 338, :right, dark, light])
    pbDrawTextPositions(overlay, textpos)
    bar_x, bar_y, bar_w = 310, 344, 140
    overlay.fill_rect(bar_x - 2, bar_y - 2, bar_w + 4, 14, Color.new(104, 104, 104))
    overlay.fill_rect(bar_x, bar_y, bar_w, 10, Color.new(200, 208, 208))
    fill = bar_w * @pokemon.contest_sheen / ContestSettings::MAX_SHEEN
    overlay.fill_rect(bar_x, bar_y, fill, 10, Color.new(248, 200, 64)) if fill > 0
  end

  # @brief Draws the Moves page, with conditions instead of types in contest mode.
  def drawPageFour
    __contests_drawPageFour
    draw_contest_move_labels(104, false) if contest_moves?
  end

  # @brief Draws the move list while a move is selected, with conditions
  # instead of types in contest mode.
  # @param move_to_learn [Symbol, nil]
  def drawPageFourSelecting(move_to_learn)
    __contests_drawPageFourSelecting(move_to_learn)
    return if !contest_moves?
    overlay = @sprites["overlay"].bitmap
    overlay.fill_rect(0, 0, 220, 54, Color.new(0, 0, 0, 0))
    pbDrawTextPositions(overlay, [[_INTL("CONTEST MOVES"), 26, 22, :left,
                                   Color.new(248, 248, 248), Color.new(104, 104, 104)]])
    draw_contest_move_labels((move_to_learn) ? 28 : 104, move_to_learn)
  end

  # @brief Covers each move's type icon with its condition label.
  # @param top [Integer] y of the first move's name, as in drawPageFour.
  # @param move_to_learn [Pokemon::Move, nil] Shown below the known moves.
  def draw_contest_move_labels(top, move_to_learn)
    overlay = @sprites["overlay"].bitmap
    y = top
    limit = (move_to_learn) ? Pokemon::MAX_MOVES + 1 : Pokemon::MAX_MOVES
    limit.times do |i|
      move = @pokemon.moves[i]
      if i == Pokemon::MAX_MOVES
        move = move_to_learn
        y += 20
      end
      ContestUI.draw_condition_label(overlay, move.contest_condition, 248, y - 4) if move
      y += 64
    end
  end

  # @brief Draws the selected move's details: battle details normally;
  # condition, appeal, jam, contest effect and contest description in
  # contest mode.
  # @param move_to_learn [Pokemon::Move, nil]
  # @param selected_move [Pokemon::Move]
  def drawSelectedMove(move_to_learn, selected_move)
    return __contests_drawSelectedMove(move_to_learn, selected_move) if !contest_moves?
    drawPageFourSelecting(move_to_learn)
    overlay = @sprites["overlay"].bitmap
    base   = Color.new(64, 64, 64)
    shadow = Color.new(176, 176, 176)
    @sprites["pokemon"].visible = false if @sprites["pokemon"]
    @sprites["pokeicon"].pokemon = @pokemon
    @sprites["pokeicon"].visible = true
    @sprites["itemicon"].visible = false if @sprites["itemicon"]
    # Replace the battle labels with contest ones
    overlay.fill_rect(0, 120, 236, 100, Color.new(0, 0, 0, 0))
    data = selected_move.contest_data
    appeal = (data&.appeal) ? data.appeal.to_s : "---"
    jam    = (data&.jam) ? data.jam.to_s : "---"
    textpos = [
      [_INTL("CONDITION"), 20, 128, :left, Color.new(248, 248, 248), Color.new(104, 104, 104)],
      [_INTL("APPEAL"), 20, 160, :left, Color.new(248, 248, 248), Color.new(104, 104, 104)],
      [_INTL("JAM"), 20, 192, :left, Color.new(248, 248, 248), Color.new(104, 104, 104)],
      [appeal, 216, 160, :right, base, shadow],
      [jam, 216, 192, :right, base, shadow]
    ]
    pbDrawTextPositions(overlay, textpos)
    ContestUI.draw_condition_label(overlay, selected_move.contest_condition, 166, 124)
    # Contest effect and description, falling back to the battle description
    effect = data&.effect_data
    description = data&.description || selected_move.description
    if effect
      pbDrawTextPositions(overlay, [[effect.name, 4, 224, :left, base, shadow]])
      drawTextEx(overlay, 4, 256, 230, 4, description, base, shadow)
    else
      drawTextEx(overlay, 4, 224, 230, 5, description, base, shadow)
    end
  end

  # @brief Runs the summary screen. Replaces the base method so there can be
  # a sixth page and the Moves page can switch to contest information.
  # @return [Integer] The party index being viewed when the screen closed.
  def pbScene
    @pokemon.play_cry
    loop do
      Graphics.update
      Input.update
      pbUpdate
      dorefresh = false
      if Input.trigger?(ContestSettings::CONTEST_MOVES_TOGGLE) && @page == 4 && !@pokemon.egg? &&
         contest_moves_enabled?
        pbPlayCursorSE
        @contest_moves = !contest_moves?
        dorefresh = true
      elsif Input.trigger?(Input::ACTION)
        pbSEStop
        @pokemon.play_cry
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        if @page == 4
          pbPlayDecisionSE
          pbMoveSelection
          dorefresh = true
        elsif @page == 5
          pbPlayDecisionSE
          pbRibbonSelection
          dorefresh = true
        elsif !@inbattle
          pbPlayDecisionSE
          dorefresh = pbOptions
        end
      elsif Input.trigger?(Input::UP) && @partyindex > 0
        oldindex = @partyindex
        pbGoToPrevious
        if @partyindex != oldindex
          pbChangePokemon
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::DOWN) && @partyindex < @party.length - 1
        oldindex = @partyindex
        pbGoToNext
        if @partyindex != oldindex
          pbChangePokemon
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::LEFT) && !@pokemon.egg?
        oldpage = @page
        @page = (@page - 1).clamp(1, summary_page_count)
        if @page != oldpage   # Move to next page
          pbSEPlay("GUI summary change page")
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::RIGHT) && !@pokemon.egg?
        oldpage = @page
        @page = (@page + 1).clamp(1, summary_page_count)
        if @page != oldpage   # Move to next page
          pbSEPlay("GUI summary change page")
          @ribbonOffset = 0
          dorefresh = true
        end
      end
      drawPage(@page) if dorefresh
    end
    return @partyindex
  end
end
