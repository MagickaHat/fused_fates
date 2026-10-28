#================================================================================================
# Pokémon Fused Fates Underground System - 009_UI.rb
#================================================================================================

#==================================================================
# class UndergroundMenu_Scene
#==================================================================
# @brief The Underground menu: spheres, statues, goods and progress.
# Uses no graphics of its own: panels are filled rectangles and text, and
# statues show the Pokémon's existing party icon.
#
# Left/Right switch tabs, Up/Down move through the list, Back closes.
class UndergroundMenu_Scene
  TABS        = [:spheres, :statues, :goods, :status].freeze
  TAB_HEIGHT  = 40
  LIST_WIDTH  = 256

  BG_COLOR     = Color.new(56, 48, 40)
  PANEL_COLOR  = Color.new(232, 224, 208)
  TAB_COLOR    = Color.new(104, 88, 72)
  TAB_SELECTED = Color.new(200, 136, 72)
  BASE_COLOR   = Color.new(64, 64, 64)
  SHADOW_COLOR = Color.new(176, 176, 176)
  LIGHT_BASE   = Color.new(248, 248, 248)
  LIGHT_SHADOW = Color.new(40, 40, 48)

  # @brief Opens the menu's sprites.
  def pbStartScene
    @tab        = 0
    @viewport   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites    = {}
    @sprites["bg"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@sprites["overlay"].bitmap)
    @sprites["list"] = Window_CommandPokemon.newWithSize([""], 0, TAB_HEIGHT, LIST_WIDTH,
                                                         Graphics.height - TAB_HEIGHT, @viewport)
    @sprites["icon"] = PokemonIconSprite.new(nil, @viewport)
    @sprites["icon"].setOffset(PictureOrigin::CENTER)
    @sprites["icon"].x = LIST_WIDTH + ((Graphics.width - LIST_WIDTH) / 2)
    @sprites["icon"].y = TAB_HEIGHT + 56
    @sprites["icon"].visible = false
    refresh_tab
    pbFadeInAndShow(@sprites) { update }
  end

  # @brief Closes the menu's sprites.
  def pbEndScene
    pbFadeOutAndHide(@sprites) { update }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  # @brief Updates every sprite.
  def update
    pbUpdateSpriteHash(@sprites)
  end

  # @brief Advances one frame.
  def pbUpdate
    Graphics.update
    Input.update
    update
  end

  # @brief Runs the menu until the player closes it.
  def pbMain
    last_index = -1
    loop do
      pbUpdate
      if Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        pbPlayCursorSE
        @tab = (@tab + (Input.trigger?(Input::LEFT) ? -1 : 1)) % TABS.length
        refresh_tab
        last_index = -1
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      end
      if @sprites["list"].index != last_index
        last_index = @sprites["list"].index
        draw_details
      end
    end
  end

  #----------------------------------------------------------------
  # Content
  #----------------------------------------------------------------
  # @brief Rows for the current tab: [label, details lines, statue ID or nil].
  # @return [Array<Array>]
  def rows
    d = Underground.data
    case TABS[@tab]
    when :spheres
      return GameData::UndergroundSphere.keys.map do |c|
        [_INTL("{1} x{2}", Underground.sphere_name(c), d.spheres[c]),
         [_INTL("Units owned: {1}", d.spheres[c]), _INTL("Buried: {1}", d.buried.count { |e| e[:color] == c })], nil]
      end
    when :statues
      ids = (d.statues.select { |_id, n| n > 0 }.keys + d.placed_statues).uniq
      return ids.map do |id|
        tier = GameData::UndergroundStatue.try_get(id)&.tier
        placed = d.placed_statues.count(id)
        [_INTL("{1} x{2}", Underground.statue_name(id), d.statues[id] + placed),
         [_INTL("Tier: {1}", tier.to_s.capitalize), _INTL("In storage: {1}", d.statues[id]),
          _INTL("On pedestals: {1}", placed)], id]
      end
    when :goods
      ids = (d.goods.select { |_id, n| n > 0 }.keys + d.placed_goods).uniq
      return ids.map do |id|
        placed = d.placed_goods.count(id)
        [_INTL("{1} x{2}", Underground.good_name(id), d.goods[id] + placed),
         [GameData::UndergroundGood.try_get(id)&.description || "", _INTL("In storage: {1}", d.goods[id]),
          _INTL("Placed: {1}", placed)], nil]
      end
    when :status
      return status_rows
    end
    return []
  end

  # @brief Rows for the status tab.
  # @return [Array<Array>]
  def status_rows
    d = Underground.data
    mission = Underground::MISSIONS[d.mission_stage]
    base = d.base_size ? _INTL(d.base_size.to_s.capitalize) : _INTL("None yet")
    location = d.base_location ? pbGetMapNameFromId(d.base_location[:map_id]) : _INTL("Not dug yet")
    lines = GameData::UndergroundLine.keys.map do |id|
      _INTL("{1}: {2}", GameData::UndergroundLine.get(id).name,
            d.repaired_lines.include?(id) ? _INTL("Running") : _INTL("Broken"))
    end
    stations = GameData::UndergroundStation.keys.select { |id| d.discovered_stations.include?(id) }
                                           .map { |id| GameData::UndergroundStation.get(id).name }
    return [
      [_INTL("Diglett meter"), [_INTL("{1}/{2}", d.diglett_meter, UndergroundSettings::DIGLETTS_PER_BONUS),
                                _INTL("Bonus digs left: {1}", d.bonus_digs)], nil],
      [_INTL("Mission"), [mission ? _INTL(mission[:intro]) : _INTL("You've mastered the Underground!")], nil],
      [_INTL("Secret Base"), [_INTL("Size: {1}", base), _INTL("Location: {1}", location),
                              _INTL("Pedestals: {1}", Underground::SecretBase.slot_count(:statue)),
                              _INTL("Goods slots: {1}", Underground::SecretBase.slot_count(:good))], nil],
      [_INTL("Mine carts"), lines, nil],
      [_INTL("Stations"), stations.empty? ? [_INTL("None found yet")] : stations, nil],
      [_INTL("Records"), [_INTL("Walls dug: {1}", d.stats[:digs]),
                          _INTL("Statues dug: {1}", d.stats[:statues_dug]),
                          _INTL("Trades: {1}", d.stats[:trades]),
                          _INTL("Sold: {1}", d.stats[:sold]),
                          _INTL("Hideaway catches: {1}", d.stats[:hideaway_catches]),
                          _INTL("Flags taken: {1}", d.stats[:flags])], nil]
    ]
  end

  # @brief Rebuilds the list for the current tab.
  def refresh_tab
    @rows = rows
    labels = @rows.map { |r| r[0] }
    labels = [_INTL("(empty)")] if labels.empty?
    @sprites["list"].commands = labels
    @sprites["list"].index = 0
    draw_background
    draw_details
  end

  # @brief Draws the tab bar and the details panel.
  def draw_background
    bmp = @sprites["bg"].bitmap
    bmp.fill_rect(0, 0, Graphics.width, Graphics.height, BG_COLOR)
    tab_w = Graphics.width / TABS.length
    TABS.each_index do |i|
      bmp.fill_rect((i * tab_w) + 2, 2, tab_w - 4, TAB_HEIGHT - 4, (i == @tab) ? TAB_SELECTED : TAB_COLOR)
    end
    bmp.fill_rect(LIST_WIDTH + 8, TAB_HEIGHT + 8, Graphics.width - LIST_WIDTH - 16,
                  Graphics.height - TAB_HEIGHT - 16, PANEL_COLOR)
  end

  # @brief Draws the tab names and the selected row's details.
  def draw_details
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    tab_w = Graphics.width / TABS.length
    names = [_INTL("Spheres"), _INTL("Statues"), _INTL("Goods"), _INTL("Status")]
    texts = names.each_with_index.map do |name, i|
      [name, (i * tab_w) + (tab_w / 2), 6, :center, LIGHT_BASE, LIGHT_SHADOW]
    end
    pbDrawTextPositions(overlay, texts)
    row = @rows[@sprites["list"].index]
    icon = @sprites["icon"]
    icon.visible = false
    return unless row
    y = TAB_HEIGHT + 20
    s = row[2] && GameData::UndergroundStatue.try_get(row[2])
    if s
      icon.pokemon = Underground::Hideaways.build_pokemon({ species: s.species, level: 1, partner: s.body })
      icon.visible = true
      y += 80
    end
    drawFormattedTextEx(overlay, LIST_WIDTH + 20, y, Graphics.width - LIST_WIDTH - 40,
                        row[1].join("\n"), BASE_COLOR, SHADOW_COLOR)
  end
end

#==================================================================
# class UndergroundMenu_Screen
#==================================================================
# @brief Runs UndergroundMenu_Scene.
class UndergroundMenu_Screen
  # @param scene [UndergroundMenu_Scene]
  def initialize(scene)
    @scene = scene
  end

  # @brief Opens the menu and waits for it to close.
  def pbStartScreen
    @scene.pbStartScene
    @scene.pbMain
    @scene.pbEndScene
  end
end

# @brief Opens the Underground menu.
def pbUndergroundMenu
  pbFadeOutIn do
    UndergroundMenu_Screen.new(UndergroundMenu_Scene.new).pbStartScreen
  end
end

MenuHandlers.add(:pause_menu, :underground, {
  "name"      => _INTL("Underground"),
  "order"     => 45,
  "condition" => proc { next Underground.in_underground? },
  "effect"    => proc { |menu|
    pbPlayDecisionSE
    pbUndergroundMenu
    menu.pbRefresh
    next false
  }
})
