#================================================================================================
# Pokémon Fused Fates Underground System - 004_Mining.rb
#================================================================================================

#==================================================================
# class UndergroundMiningScene
#==================================================================
# @class UndergroundMiningScene
# @brief The base game's mining minigame with an Underground treasure table.
#
# Treasures use the base game's ITEMS format:
#   [reward, weight, graphic x, graphic y, width, height, pattern]
# where reward is an item ID, or { sphere: color, units: range } for spheres.
# MiningGameScene's methods read its ITEMS constant directly, so every method
# that touches it is redefined here to read #table instead.
class UndergroundMiningScene < MiningGameScene
  # @brief Item IDs of which only one per wall can be buried.
  FOSSILS = [:DOMEFOSSIL, :HELIXFOSSIL, :OLDAMBER, :ROOTFOSSIL,
             :SKULLFOSSIL, :ARMORFOSSIL, :CLAWFOSSIL]
  # @brief Item IDs of which only one per wall can be buried.
  PLATES = [:INSECTPLATE, :DREADPLATE, :DRACOPLATE, :ZAPPLATE, :FISTPLATE,
            :FLAMEPLATE, :MEADOWPLATE, :EARTHPLATE, :ICICLEPLATE, :TOXICPLATE,
            :MINDPLATE, :STONEPLATE, :SKYPLATE, :SPOOKYPLATE, :IRONPLATE, :SPLASHPLATE]

  # @brief The treasure table this wall was filled from.
  attr_reader :table

  # @param table [Array<Array>] Treasures, in the format above.
  # @param bonus [Boolean] Whether this is a bonus dig (buries extra treasures).
  def initialize(table, bonus = false)
    @table = table
    @bonus = bonus
  end

  # @brief Whether every treasure in the wall was dug up.
  # @return [Boolean]
  def cleared?
    return !@items.nil? && !@items.empty? && @items.all? { |i| i[3] }
  end

  # @brief Buries a few treasures from the table and draws them on the item layer.
  def pbDistributeItems
    ptotal = @table.sum { |t| t[1] }
    numitems = rand(UndergroundSettings::MINING_ITEMS_RANGE)
    numitems += UndergroundSettings::BONUS_DIG_EXTRA_ITEMS if @bonus
    tries = 0
    while numitems > 0 && tries < 500
      tries += 1
      rnd = rand(ptotal)
      index = @table.index { |t| (rnd -= t[1]) < 0 }
      next if index.nil? || !can_bury?(index)
      t = @table[index]
      50.times do
        provx = rand(BOARD_WIDTH - t[4] + 1)
        provy = rand(BOARD_HEIGHT - t[5] + 1)
        next unless pbCheckOverlaps(false, provx, provy, t[4], t[5], t[6])
        @items.push([index, provx, provy])
        numitems -= 1
        break
      end
    end
    layer = @sprites["itemlayer"].bitmap
    @items.each do |i|
      t = @table[i[0]]
      layer.blt(32 * i[1], 64 + (32 * i[2]), @itembitmap.bitmap,
                Rect.new(32 * t[2], 32 * t[3], 32 * t[4], 32 * t[5]))
    end
  end

  # @brief Whether a treasure can join the ones already buried.
  # @param index [Integer] Index into #table.
  # @return [Boolean]
  def can_bury?(index)
    reward = @table[index][0]
    return true if reward == :HEARTSCALE
    @items.each do |i|
      return false if i[0] == index
      pre = @table[i[0]][0]
      return false if FOSSILS.include?(pre) && FOSSILS.include?(reward)
      return false if PLATES.include?(pre) && PLATES.include?(reward)
    end
    return true
  end

  # @brief Kept for compatibility with MiningGameScene; checks by reward.
  # @param newitem [Symbol, Hash]
  # @return [Boolean]
  def pbNoDuplicateItems(newitem)
    index = @table.index { |t| t[0] == newitem }
    return index.nil? || can_bury?(index)
  end

  # @brief Whether a shape can go at a position without overlapping buried
  # treasures (and iron, if checkiron is set).
  def pbCheckOverlaps(checkiron, provx, provy, provwidth, provheight, provpattern)
    shapes = @items.map { |i| [i[1], i[2], @table[i[0]][4], @table[i[0]][5], @table[i[0]][6]] }
    if checkiron
      shapes += @iron.map { |i| [i[1], i[2], IRON[i[0]][2], IRON[i[0]][3], IRON[i[0]][4]] }
    end
    shapes.each do |prex, prey, prewidth, preheight, prepattern|
      next if provx + provwidth <= prex || provx >= prex + prewidth ||
              provy + provheight <= prey || provy >= prey + preheight
      prepattern.length.times do |j|
        next if prepattern[j] == 0
        xco = prex + (j % prewidth)
        yco = prey + (j / prewidth)
        next if provx + provwidth <= xco || provx > xco ||
                provy + provheight <= yco || provy > yco
        return false if provpattern[xco - provx + ((yco - provy) * provwidth)] == 1
      end
    end
    return true
  end

  # @brief Whether a board position covers part of a buried treasure.
  # @param position [Integer]
  # @return [Boolean]
  def pbIsItemThere?(position)
    posx = position % BOARD_WIDTH
    posy = position / BOARD_WIDTH
    @items.each do |i|
      t = @table[i[0]]
      next if posx < i[1] || posx >= i[1] + t[4]
      next if posy < i[2] || posy >= i[2] + t[5]
      return true if t[6][(posx - i[1]) + ((posy - i[2]) * t[4])] > 0
    end
    return false
  end

  # @brief Indices of buried treasures that have just been fully uncovered.
  # @return [Array<Integer>]
  def pbCheckRevealed
    ret = []
    @items.each_with_index do |item, i|
      next if item[3]
      t = @table[item[0]]
      revealed = (0...t[5]).all? do |j|
        (0...t[4]).all? do |k|
          tile = @sprites["tile#{item[1] + k + ((item[2] + j) * BOARD_WIDTH)}"]
          tile.layer <= 0 || t[6][k + (j * t[4])] <= 0
        end
      end
      ret.push(i) if revealed
    end
    return ret
  end

  # @brief Flashes newly uncovered treasures and marks them as won.
  # @param revealed [Array<Integer>]
  def pbFlashItems(revealed)
    return if revealed.empty?
    flash = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    flash.z = 15
    flash.color = Color.new(255, 255, 255, 0)
    revealed.each do |index|
      item = @items[index]
      t = @table[item[0]]
      flash.bitmap.blt(32 * item[1], 64 + (32 * item[2]), @itembitmap.bitmap,
                       Rect.new(32 * t[2], 32 * t[3], 32 * t[4], 32 * t[5]))
    end
    duration = 0.25
    [[0, 255], [255, 0]].each do |alpha_start, alpha_end|
      timer_start = System.uptime
      loop do
        alpha = lerp(alpha_start, alpha_end, duration / 2, timer_start, System.uptime)
        flash.color.alpha = alpha
        update
        Graphics.update
        break if alpha == alpha_end
      end
    end
    flash.dispose
    revealed.each do |index|
      @items[index][3] = true
      @itemswon.push(@table[@items[index][0]][0])
    end
  end

  # @brief Hands out everything dug up: items go to the Bag, spheres to the
  # Underground save data.
  def pbGiveItems
    @itemswon.each do |reward|
      if reward.is_a?(Hash)
        units = rand(reward[:units])
        Underground.add_spheres(reward[:sphere], units)
        pbMessage(_INTL("You got {1} {2} units!", units, Underground.sphere_name(reward[:sphere])) +
                  "\\se[Mining item get]\\wtnp[30]")
      elsif $bag.add(reward)
        pbMessage(_INTL("One {1} was obtained.", GameData::Item.get(reward).name) +
                  "\\se[Mining item get]\\wtnp[30]")
      else
        pbMessage(_INTL("One {1} was found, but you have no room for it.",
                        GameData::Item.get(reward).name))
      end
    end
  end
end

#==================================================================
# module Underground
#==================================================================
module Underground
  #==================================================================
  # module Mining
  #==================================================================
  # @brief Builds walls from the treasure tables and hands out statue finds.
  module Mining
    module_function

    # @brief The treasure table settings for a dig spot, with anything it
    # leaves out filled in from :default.
    # @param map_id [Integer]
    # @param key [Symbol, String, nil] The dig spot's own table name, if any.
    # @return [Hash] { spheres:, items:, weights:, statues: }
    def table_for(map_id, key = nil)
      default = MINING_TABLES[:default]
      table = nil
      table = MINING_TABLES[key.to_sym] if key && !key.to_s.empty?
      table ||= MINING_TABLES[map_id]
      table = MINING_TABLES[table] if table.is_a?(Symbol)
      return default.merge(table || {})
    end

    # @brief The treasures that can be buried in a wall.
    # @param bonus [Boolean] Bonus digs make rare treasures more likely.
    # @param table [Hash] From #table_for; defaults to :default.
    # @return [Array<Array>] Treasures in UndergroundMiningScene's format.
    def treasure_pool(bonus = false, table = nil)
      table ||= table_for(nil)
      weights = table[:weights] || {}
      pool = (table[:spheres] || SPHERE_TREASURES).map do |s|
        x, y = SPHERES[s[:color]][s[:large] ? :large : :small]
        size = s[:large] ? 3 : 2
        [{ sphere: s[:color], units: s[:units] }, s[:weight], x, y, size, size, [1] * (size * size)]
      end
      MiningGameScene::ITEMS.each do |entry|
        next unless GameData::Item.exists?(entry[0])
        next unless table[:items] == :all || Array(table[:items]).include?(entry[0])
        pool.push(entry.dup)
      end
      pool.each do |t|
        id = t[0].is_a?(Hash) ? t[0][:sphere] : t[0]
        t[1] = [(t[1] * weights[id]).round, 1].max if weights[id]
      end
      if bonus
        pool.each do |t|
          t[1] *= UndergroundSettings::BONUS_RARE_MULTIPLIER if t[1] <= UndergroundSettings::RARE_TREASURE_WEIGHT
        end
      end
      return pool
    end

    # @brief Statue tiers the player can dig at their mission stage.
    # @return [Array<Symbol>]
    def unlocked_statue_tiers
      stage = Underground.data.mission_stage
      return UndergroundSettings::STATUE_TIER_STAGE.select { |_tier, min| stage >= min }.keys
    end

    # @brief Rolls for a statue behind a cleared wall.
    # @param bonus [Boolean]
    # @param rng [Random]
    # @param pool [Array<Symbol>, nil] Statue IDs findable here; nil for all.
    # @return [Symbol, nil] Statue ID found, or nil.
    def roll_statue(bonus = false, rng = Random, pool = nil)
      tiers = unlocked_statue_tiers
      return nil if tiers.empty?
      chance = bonus ? UndergroundSettings::BONUS_STATUE_FIND_CHANCE : UndergroundSettings::STATUE_FIND_CHANCE
      return nil if rng.rand(100) >= chance
      ids = pool || STATUES.keys
      by_tier = tiers.to_h { |tier| [tier, ids.select { |id| STATUES.dig(id, :tier) == tier }] }
      by_tier.delete_if { |_tier, list| list.empty? }
      return nil if by_tier.empty?
      tier = :common
      tier = :rare if by_tier.key?(:rare) && rng.rand(100) < UndergroundSettings::RARE_STATUE_SHARE
      tier = by_tier.keys.first unless by_tier.key?(tier)
      choices = by_tier[tier]
      return choices[rng.rand(choices.length)]
    end

    # @brief Runs one dig: the minigame, its rewards, and a possible statue find.
    # @param map_id [Integer, nil] The dig spot's map; defaults to the current map.
    # @param key [Symbol, String, nil] The dig spot's own table name, if any.
    def start(map_id = nil, key = nil)
      table = table_for(map_id || $game_map.map_id, key)
      d = Underground.data
      bonus = d.bonus_digs > 0
      if bonus
        d.bonus_digs -= 1
        pbMessage(_INTL("It's a bonus dig! Rare treasures are easier to find. ({1} left)", d.bonus_digs))
      end
      scene = UndergroundMiningScene.new(treasure_pool(bonus, table), bonus)
      pbFadeOutIn { MiningGame.new(scene).pbStartScreen }
      d.stats[:digs] += 1
      return unless scene.cleared?
      statue = roll_statue(bonus, Random, table[:statues])
      return unless statue
      Underground.grant_statue(statue)
      d.stats[:statues_dug] += 1
      pbMessage(_INTL("Something was lodged deep behind the wall...\\nYou found a {1}!",
                      Underground.statue_name(statue)) + "\\se[Mining found all]")
    end
  end
end
